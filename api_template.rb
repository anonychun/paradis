require "fileutils"
require "shellwords"

if __FILE__ =~ %r{\Ahttps?://}
  require "tmpdir"
  source_paths.unshift(tempdir = Dir.mktmpdir("paradis-"))
  at_exit { FileUtils.remove_entry(tempdir) }
  git clone: [
    "--quiet",
    "https://github.com/anonychun/paradis.git",
    tempdir
  ].map(&:shellescape).join(" ")

  if (branch = __FILE__[%r{paradis/(.+)/api_template.rb}, 1])
    Dir.chdir(tempdir) { git checkout: branch }
  end
else
  source_paths.unshift(File.dirname(__FILE__))
end

apply "template.rb"

insert_into_file "config/routes.rb", after: "mount MissionControl::Jobs::Engine, at: \"/jobs\"\n" do
  <<~RUBY.indent(2).prepend("\n")
    namespace :api do
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

file "app/errors/api_error.rb", <<~RUBY
  class ApiError < ApplicationError
    attr_reader :status, :errors

    def initialize(errors: {}, status: 500)
      @errors = errors.is_a?(String) ? {message: errors} : errors
      @status = status
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
        when ActiveRecord::RecordNotFound
          status = 404
          errors = {message: "\#{e.model} tidak ditemukan"}
        else
          status = 500
          errors = {message: "Terjadi kesalahan, silakan coba lagi"}

          Rails.logger.error "Unhandled exception: \#{e}"
        end

        present_meta(:trace, e) if Rails.env.local? || ENV["DEBUGGING"].eql?("1")
        render_json(errors: errors, status: status)
      end
    end
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

    def present(data)
      if data.is_a?(Hash)
        Current.api_ctx[:data].merge!(data)
      else
        Current.api_ctx[:data] = data
      end
    end

    def error!(errors, status = 500)
      raise ApiError.new(errors: errors, status: status)
    end

    def param_error!(key, *messages)
      error!({params: {key => messages}}, 400)
    end

    def render_json(meta: nil, data: nil, errors: nil, status: 200)
      present_meta(meta) unless meta.nil?
      present(data) unless data.nil?

      ok = status < 400 || errors.blank?
      render json: {
        ok: ok,
        meta: Current.api_ctx[:meta].empty? ? nil : Current.api_ctx[:meta],
        data: ok ? Current.api_ctx[:data] : nil,
        errors: ok ? nil : errors
      }.to_json(serializable: true),
        status: status
    end
  end
RUBY

lib "api/helpers/paginator.rb", <<~RUBY
  module Api::Helpers::Paginator
    def paginate(collection)
      params[:page] ||= 1
      params[:per_page] ||= 10

      params.validate! do
        required(:page).filled(:integer, gt?: 0)
        required(:per_page).filled(:integer, gt?: 0, lteq?: 500)
        optional(:start_date).filled(:date_time)
        optional(:end_date).filled(:date_time)
      end

      if params[:start_date].present?
        collection = collection.where(created_at: params[:start_date]..)
      end

      if params[:end_date].present?
        collection = collection.where(created_at: ..params[:end_date])
      end

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
      collection
    end
  end
RUBY

lib "api/helpers.rb", <<~RUBY
  module Api::Helpers
    extend ActiveSupport::Concern

    include ExceptionHandler
    include Presenter
    include Paginator

    def local_request?
      origin = headers["origin"]
      return true unless origin.present?

      prefixes = [
        "http://localhost", "https://localhost",
        "http://127.0.0.1", "https://127.0.0.1",
        "http://0.0.0.0", "https://0.0.0.0"
      ]
      prefixes.each do |prefix|
        return true if origin.start_with?(prefix + ":")
        return true if prefix.eql?(origin)
      end

      false
    end
  end
RUBY

file "app/controllers/api_controller.rb", <<~RUBY
  class ApiController < ApplicationController
    include Api::Helpers
  end
RUBY

file "app/controllers/api/v1_controller.rb", <<~RUBY
  class Api::V1Controller < ApiController
  end
RUBY
