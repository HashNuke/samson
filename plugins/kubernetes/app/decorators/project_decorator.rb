Project.class_eval do
  has_many :kubernetes_releases, through: :builds, class_name: 'Kubernetes::Release'
  has_many :roles, class_name: 'Kubernetes::Role'

  def file_from_repo(path, git_ref, ttl: 1.hour)
    # Caching by Git reference
    Rails.cache.fetch([git_ref, path], expire_in: ttl) do
      data = GITHUB.contents(github_repo, path: path, ref: git_ref)
      Base64.decode64(data[:content])
    end
  rescue Octokit::NotFound
    nil
  end

  def directory_contents_from_repo(path, git_ref, ttl: 1.hour)
    # Caching by Git reference
    Rails.cache.fetch([git_ref, path], expire_in: ttl) do
      GITHUB.contents(github_repo, path: path, ref: git_ref).map(&:path).select { |file_name|
        file_name.ends_with?('.yml', '.yaml', '.json')
      }
    end
  end

  def refresh_kubernetes_roles!(git_ref)
    config_files = directory_contents_from_repo('kubernetes', git_ref)

    # Soft deletes all the current kubernetes roles
    roles.each(&:soft_delete!)

    # Imports the new kubernetes roles
    imported = import_kubernetes_roles(config_files, git_ref) do |role|
      roles.build(
        config_file: role.file_path,
        name: role.replication_controller.labels[:role],
        service_name: role.service.name,
        ram: role.replication_controller.pod_template.container.ram,
        cpu: role.replication_controller.pod_template.container.cpu,
        replicas: role.replication_controller.replicas,
        deploy_strategy: role.replication_controller.deploy_strategy
      )
    end

    # Saves the new roles into the database
    imported.each(&:save!)
  end

  private

  # Given a list of kubernetes configuration files, retrieves the corresponding contents
  # and builds the corresponding Kubernetes Roles
  def import_kubernetes_roles(config_files, git_ref)
    config_files.map do |file|
      file_contents = file_from_repo(file, git_ref)
      config_file = Kubernetes::RoleConfigFile.new(file_contents, file)
      yield config_file if block_given?
    end
  end
end
