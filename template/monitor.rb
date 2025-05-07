add_gem "mission_control-jobs"
add_gem "solid_errors"

inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do" do
  <<~RUBY.indent(2).prepend("\n")
    mount MissionControl::Jobs::Engine, at: "jobs"
    mount SolidErrors::Engine, at: "errors"
  RUBY
end

after_bundle do
  rails_command "generate solid_errors:install"

  gsub_file "config/environments/production.rb",
    "config.solid_errors.send_emails = true",
    "config.solid_errors.send_emails = false"

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
end
