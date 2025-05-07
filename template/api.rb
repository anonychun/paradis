add_gem "dry-schema"
add_gem "grape-entity"

initializer "action_controller.rb", <<~RUBY
  ActionController::Parameters.class_eval do
    def validate!(schema = nil, &)
      schema ||= Dry::Schema.Params(&)
      result = schema.call(to_unsafe_h)

      unless result.success?
        raise ApiError.new(
          errors: {params: result.errors(locale: :id).to_h},
          status: :unprocessable_entity
        )
      end

      merge!(result.to_h)
    end
  end
RUBY

initializer "dry_schema.rb", <<~RUBY
  module DryTypes
    include Dry.Types()
  end

  TypeContainer = Dry::Schema::TypeContainer.new

  TypeContainer.register(
    "params.file",
    DryTypes.Instance(ActionDispatch::Http::UploadedFile)
  )

  Dry::Schema.config.types = TypeContainer
  Dry::Schema.config.messages.backend = :i18n
RUBY

inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do" do
  <<~RUBY.indent(2).prepend("\n")
    namespace :api, defaults: {format: :json} do
      namespace :v1 do
      end
    end
  RUBY
end

file "app/models/current.rb", <<~RUBY
  class Current < ActiveSupport::CurrentAttributes
    attribute :api_ctx
  end
RUBY

file "app/entities/application_entity.rb", <<~RUBY
  class ApplicationEntity < Grape::Entity
  end
RUBY

file "app/errors/api_error.rb", <<~RUBY
  class ApiError < ApplicationError
    attr_reader :status, :errors

    def initialize(errors: {}, status: :internal_server_error)
      @errors = errors.is_a?(String) ? {message: errors} : errors
      @status = status
    end
  end
RUBY

file "app/helpers/api_helper.rb", <<~RUBY
  module ApiHelper
    def present(json, &)
      ok = response.status >= 100 && response.status < 400
      json.ok ok
      json.meta Current.api_ctx[:meta].empty? ? nil : Current.api_ctx[:meta]

      if ok
        json.data(&)
        json.errors nil
      else
        json.data nil
        json.errors(&)
      end
    end
  end
RUBY

file "app/views/api/_api.json.jbuilder", <<~RUBY
  present json do
    json.merge! body
  end
RUBY

lib "api/helpers/presenter.rb", <<~RUBY
  module Api::Helpers::Presenter
    extend ActiveSupport::Concern

    included do
      before_action do
        Current.api_ctx = Hash.new { |h, k| h[k] = {} }
      end
    end

    def present_meta(key, value)
      Current.api_ctx[:meta][key] = value
    end

    def error!(errors, status = :internal_server_error)
      raise ApiError.new(errors: errors, status: status)
    end

    def param_error!(key, *messages)
      error!({params: {key => messages}}, :unprocessable_entity)
    end

    def present(json: nil, status: :ok)
      render template: "api/_api", status: status, locals: {body: json}
    end

    def present_success
      present json: {
        message: :ok
      }
    end
  end
RUBY

lib "api/helpers/exception_handler.rb", <<~RUBY
  module Api::Helpers::ExceptionHandler
    extend ActiveSupport::Concern

    included do
      rescue_from StandardError do |e|
        case e
        when ApiError
          status = e.status
          errors = e.errors
        when ActionDispatch::Http::Parameters::ParseError
          status = :unprocessable_entity
          errors = {message: "Permintaan tidak valid"}
        when ActiveRecord::RecordInvalid
          status = :unprocessable_entity
          errors = {validations: e.record.errors.full_messages}
        when ActiveRecord::RecordNotFound
          status = :not_found
          errors = {message: "\#{e.model} tidak ditemukan"}
        else
          status = :internal_server_error
          errors = {message: "Terjadi kesalahan, silakan coba lagi"}

          if Rails.env.local?
            raise e
          else
            Rails.error.report(e)
          end
        end

        if ENV["DEBUG"].eql?("1")
          present_meta(:trace, {
            class: e.class.name,
            exception: e
          })
        end

        present json: errors, status: status
      end
    end
  end
RUBY

lib "api/helpers/paginator.rb", <<~RUBY
  module Api::Helpers::Paginator
    def paginate(collection)
      params.validate! do
        optional(:page).filled(:integer, gt?: 0)
        optional(:per_page).filled(:integer, gt?: 0)
        optional(:start_date).filled(:date_time)
        optional(:end_date).filled(:date_time)
      end

      if params[:start_date].present?
        collection = collection.where(created_at: params[:start_date]..)
      end

      if params[:end_date].present?
        collection = collection.where(created_at: ..params[:end_date])
      end

      if params[:page].present? && params[:per_page].present?
        total = collection.count
        collection = collection
          .limit(params[:per_page])
          .offset((params[:page] - 1) * params[:per_page])

        meta_pagination = {
          page: params[:page],
          per_page: params[:per_page],
          total: total
        }

        present_meta :pagination, meta_pagination
      end

      collection
    end
  end
RUBY

lib "api/helpers.rb", <<~RUBY
  module Api::Helpers
    extend ActiveSupport::Concern

    include Presenter
    include ExceptionHandler
    include Paginator
  end
RUBY

file "app/controllers/api_controller.rb", <<~RUBY
  class ApiController < ActionController::API
    include ActionController::Cookies

    include Api::Helpers
  end
RUBY

file "app/controllers/api/v1_controller.rb", <<~RUBY
  class Api::V1Controller < ApiController
  end
RUBY
