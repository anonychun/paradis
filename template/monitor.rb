add_gem "mission_control-jobs"
add_gem "solid_errors"

inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do" do
  <<~RUBY.indent(2).prepend("\n")
    mount MissionControl::Jobs::Engine, at: "jobs"
    mount SolidErrors::Engine, at: "errors"
  RUBY
end

after_bundle do
  generate "solid_errors:install"

  gsub_file "config/environments/production.rb",
    "config.solid_errors.send_emails = true",
    "config.solid_errors.send_emails = false"

  gsub_file "config/environments/production.rb",
    "config.solid_errors.username = Rails.application.credentials.dig(:solid_errors, :username)",
    "config.solid_errors.username = ENV.fetch(\"DEV_USER\", \"\")"

  gsub_file "config/environments/production.rb",
    "config.solid_errors.password = Rails.application.credentials.dig(:solid_errors, :password)",
    "config.solid_errors.password = ENV.fetch(\"DEV_PASSWORD\", \"\")"

  inject_into_file "config/database.yml", before: "  cache:" do
    if options[:database] == "sqlite3"
      <<~YAML.indent(2)
        errors:
          <<: *default
          database: storage/production_errors.sqlite3
          migrations_paths: db/errors_migrate
      YAML
    else
      <<~YAML.indent(2)
        errors:
          <<: *primary_production
          database: #{@app_name}_production_errors
          migrations_paths: db/errors_migrate
      YAML
    end
  end

  file "app/controllers/dev_controller.rb", <<~RUBY
    class DevController < ApplicationController
      http_basic_authenticate_with(
        name: ENV.fetch("DEV_USER", ""),
        password: ENV.fetch("DEV_PASSWORD", "")
      )
    end
  RUBY

  inject_into_file "config/environments/production.rb", before: "  # Configure Solid Errors" do
    <<~RUBY.indent(2).prepend("\n").concat("\n")
      config.solid_queue.preserve_finished_jobs = false
      config.mission_control.jobs.http_basic_auth_enabled = false
      config.mission_control.jobs.base_controller_class = "DevController"
    RUBY
  end
end
