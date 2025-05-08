insert_into_file "bin/docker-entrypoint", after: "  ./bin/rails db:prepare" do
  <<~RUBY.indent(2).prepend("\n").chomp
    ./bin/rails db:seed
  RUBY
end

gsub_file "Dockerfile",
  "BUNDLE_WITHOUT=\"development\"",
  "BUNDLE_WITHOUT=\"development:test\""

insert_into_file "Dockerfile", after: "ENV RAILS_ENV=\"production\" \\" do
  <<~RUBY.indent(4).prepend("\n").chomp
    WEB_CONCURRENCY="auto" \\
    RUBY_YJIT_ENABLE="1" \\
    SOLID_QUEUE_IN_PUMA="1" \\
  RUBY
end

insert_into_file "Dockerfile", after: "apt-get install --no-install-recommends -y curl" do
  <<~RUBY.prepend(" ").chomp
    tmux dumb-init
  RUBY
end

gsub_file "Dockerfile",
  "ENTRYPOINT [\"/rails/bin/docker-entrypoint\"]",
  "ENTRYPOINT [\"/usr/bin/dumb-init\", \"--\", \"/rails/bin/docker-entrypoint\"]"
