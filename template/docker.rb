gsub_file "Dockerfile", "BUNDLE_WITHOUT=\"development\"", "BUNDLE_WITHOUT=\"development:test\""

inject_into_file "Dockerfile", after: "ENV RAILS_ENV=\"production\" \\" do
  <<~RUBY.indent(4).prepend("\n").chomp
    WEB_CONCURRENCY="auto" \\
    RUBY_YJIT_ENABLE="1" \\
    SOLID_QUEUE_IN_PUMA="1" \\
  RUBY
end
