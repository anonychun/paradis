def gem_exists?(name)
  IO.read("Gemfile") =~ /^\s*gem ['"]#{name}['"]/
end

def add_gem(name, *options)
  gem(name, *options) unless gem_exists?(name)
end

gem_group :development, :test do
  add_gem "dotenv"
end

gem_group :development do
  add_gem "standard"
end

add_gem "ostruct"
add_gem "dry-schema"
add_gem "grape-entity"
add_gem "rapidjson"
add_gem "mission_control-jobs"

copy_file "config/locales/id.yml"

environment "config.i18n.default_locale = :id"
environment "config.solid_queue.preserve_finished_jobs = false"

insert_into_file "config/routes.rb", after: "Rails.application.routes.draw do" do
  <<~RUBY.indent(2).prepend("\n")
    mount MissionControl::Jobs::Engine, at: "/jobs"
  RUBY
end

initializer "action_controller.rb", <<~RUBY
  ActionController::Parameters.class_eval do
    def validate!(&)
      schema = Dry::Schema.Params do
        config.messages.backend = :i18n
      end

      schema = schema.merge(Dry::Schema.Params(&))
      result = schema.call(to_unsafe_h)
      unless result.success?
        raise ApiError.new(errors: {params: result.errors.to_h}, status: 400)
      end

      merge!(result.to_h)
    end
  end
RUBY

initializer "rapidjson.rb", <<~RUBY
  ActiveSupport::JSON::Encoding.json_encoder = RapidJSON::ActiveSupportEncoder
RUBY

initializer "clear_local_log.rb", <<~RUBY
  if Rails.env.local?
    require "rails/tasks"
    Rake::Task["log:clear"].invoke
  end
RUBY

file "app/services/application_service.rb", <<~RUBY
  class ApplicationService
    def self.call(**)
      new(**).call
    end
  end
RUBY

file "app/entities/application_entity.rb", <<~RUBY
  class ApplicationEntity < Grape::Entity
    expose :id
    expose :created_at
    expose :updated_at
  end
RUBY

file "app/utils/util.rb", <<~RUBY
  module Util
  end
RUBY

if options[:database] == "sqlite3"
  add_gem "ulid"

  initializer "active_record.rb", <<~RUBY
    ActiveRecord::Base.class_eval do
      before_create :assign_id

      private def assign_id
        if self.class.name.start_with?("ActiveStorage::")
          self.id ||= Util.generate_id
        end
      end
    end
  RUBY

  initializer "generators.rb", <<~RUBY
    Rails.application.config.generators do |g|
      g.orm :active_record, primary_key_type: :text
      g.test_framework nil
    end
  RUBY

  inject_into_module "app/utils/util.rb", "Util", <<~RUBY.indent(2)
    def generate_id
      ULID.generate
    end
  RUBY
else
  initializer "generators.rb", <<~RUBY
    Rails.application.config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
      g.test_framework nil
    end
  RUBY

  inject_into_module "app/utils/util.rb", "Util", <<~RUBY.indent(2)
    def generate_id
      SecureRandom.uuid_v7
    end
  RUBY
end

if options[:database] == "postgresql"
  initializer "active_record.rb", <<~RUBY
    require "active_record/connection_adapters/postgresql_adapter"

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz
    ActiveRecord::Base.time_zone_aware_types << :timestamptz
  RUBY
end

inject_into_class "app/models/application_record.rb", "ApplicationRecord", <<~RUBY.indent(2)
  before_create :assign_id

  private def assign_id
    self.id ||= Util.generate_id
  end
RUBY

inject_into_module "app/utils/util.rb", "Util", <<~RUBY.indent(2).concat("\n")
  module_function
RUBY

file "app/errors/application_error.rb", <<~RUBY
  class ApplicationError < StandardError
  end
RUBY

ignored_files = <<~TXT.prepend("\n")
  # Folder for JetBrains IDEs
  /.idea/

  # Folder for Visual Studio Code
  /.vscode/

  # misc
  .DS_Store
TXT

append_to_file ".gitignore", ignored_files
append_to_file ".dockerignore", ignored_files
