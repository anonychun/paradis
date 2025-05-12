add_gem "view_component"

create_file "app/components/application_component.rb", <<~RUBY
  class ApplicationComponent < ViewComponent::Base
  end
RUBY
