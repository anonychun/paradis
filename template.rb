require "fileutils"
require "shellwords"

if __FILE__.match?(%r{\Ahttps?://})
  require "tmpdir"
  source_paths.unshift(tempdir = Dir.mktmpdir("paradis-"))
  at_exit { FileUtils.remove_entry(tempdir) }
  git clone: [
    "--quiet",
    "https://github.com/anonychun/paradis.git",
    tempdir
  ].map(&:shellescape).join(" ")

  if (branch = __FILE__[%r{paradis/(.+)/template.rb}, 1])
    Dir.chdir(tempdir) { git checkout: branch }
  end
else
  source_paths.unshift(File.dirname(__FILE__))
end

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

add_gem "mission_control-jobs"

copy_file "config/locales/id.yml"

application "config.solid_queue.preserve_finished_jobs = false"

insert_into_file "config/routes.rb", after: "Rails.application.routes.draw do" do
  <<~RUBY.indent(2).prepend("\n")
    mount MissionControl::Jobs::Engine, at: "/jobs"
  RUBY
end

initializer "clear_local_log.rb", <<~RUBY
  if Rails.env.local?
    require "rails/tasks"
    Rake::Task["log:clear"].invoke
  end
RUBY

initializer "generators.rb", <<~RUBY
  Rails.application.config.generators do |g|
    g.orm :active_record, primary_key_type: :uuid
    g.assets false
    g.helper false
    g.test_framework nil
  end
RUBY

initializer "active_record.rb", <<~RUBY
  ActiveSupport.on_load(:active_record_postgresqladapter) do
    self.datetime_type = :timestamptz
  end

  ActiveRecord::Base.class_eval do
    before_create :assign_id

    private def assign_id
      if self.class.name.start_with?("ActiveStorage::")
        self.id ||= Util.generate_id
      end
    end
  end
RUBY

file "app/constants/constant.rb", <<~RUBY
  module Constant
  end
RUBY

file "app/services/service.rb", <<~RUBY
  module Service
    module_function
  end
RUBY

file "app/utils/util.rb", <<~RUBY
  module Util
    module_function

    def generate_id
      SecureRandom.uuid_v7
    end
  end
RUBY

file "app/errors/application_error.rb", <<~RUBY
  class ApplicationError < StandardError
  end
RUBY

inject_into_class "app/models/application_record.rb", "ApplicationRecord", <<~RUBY.indent(2)
  before_create :assign_id

  private def assign_id
    self.id ||= Util.generate_id
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

apply "template/api.rb"
