primary_key_type = options[:database].eql?("sqlite3") ? :text : :uuid

insert_into_file "config/initializers/generators.rb", after: "Rails.application.config.generators do |g|" do
  <<~RUBY.indent(2).prepend("\n").chomp
    g.orm :active_record, primary_key_type: :#{primary_key_type}
  RUBY
end

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

insert_into_file "app/models/application_record.rb", before: /^end\s*$/ do
  <<~RUBY.indent(2).prepend("\n")
    before_create :assign_id

    private def assign_id
      self.id ||= Util.generate_id
    end
  RUBY
end
