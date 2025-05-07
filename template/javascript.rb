after_bundle do
  pnpm_version = `pnpm --version`[/\d+\.\d+\.\d+/]
  yarn_lock_path = File.join(destination_root, "yarn.lock")

  if pnpm_version.present? && File.exist?(yarn_lock_path)
    gsub_file "Dockerfile", /ARG YARN_VERSION=\d+\.\d+\.\d+/, "ARG PNPM_VERSION=#{pnpm_version}"
    gsub_file "Dockerfile", "YARN_VERSION", "PNPM_VERSION"
    gsub_file "Dockerfile", "yarn.lock", "pnpm-lock.yaml"
    gsub_file "Dockerfile", "yarn install --immutable", "pnpm install --frozen-lockfile"
    gsub_file "Dockerfile", "yarn", "pnpm"

    gsub_file "Procfile.dev", "yarn build --watch", "pnpm build --watch"
    gsub_file "Procfile.dev", "yarn build:css --watch", "pnpm build:css --watch"

    gsub_file "bin/setup", "yarn install --check-files", "pnpm install"

    remove_file "yarn.lock"
    remove_dir "node_modules"
    run "pnpm install"
  end
end
