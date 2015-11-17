

Project.class_eval do
  has_many :kubernetes_releases, through: :builds, class_name: 'Kubernetes::Release'
  has_many :roles, class_name: 'Kubernetes::Role'

  def file_from_repo(path, git_ref, ttl: 1.hour)
    Rails.cache.fetch([self, path], expire_in: ttl) do
      data = GITHUB.contents(github_repo, path: path, ref: git_ref)
      Base64.decode64(data[:content])
    end
  rescue Octokit::NotFound
    nil
  end

  def refresh_kubernetes_roles!(git_ref)
    config_files = kubernetes_config_files(git_ref)
    imported_roles = import_kubernetes_roles(config_files, git_ref)

    # Soft deletes all the current kubernetes roles
    Kubernetes::Role.soft_delete_all!(roles)

    # Saves the new roles into the database
    imported_roles.each(&:save!)
  end

  private

  # Gets the kubernetes configuration files for the current project and the given
  # Git reference
  def kubernetes_config_files(git_ref)
    repository.directory_contents(git_ref, path: 'kubernetes').select { |file|
      file.ends_with?('.yml', '.yaml', '.json')
    }
  end

  # Given a list of kubernetes configuration files, retrieves the corresponding contents
  # and builds the corresponding Kubernetes Roles
  def import_kubernetes_roles(config_files, git_ref)
    config_files.map do |file|
      file_contents = file_from_repo(file, git_ref)
      config_file = Kubernetes::RoleConfigFile.new(file_contents, file)

      roles.build(
        name: config_file.replication_controller.labels[:role],
        config_file: file,
        service_name: config_file.service.name,
        ram: config_file.replication_controller.pod_template.container.ram,
        cpu: config_file.replication_controller.pod_template.container.cpu,
        replicas: config_file.replication_controller.replicas,
        deploy_strategy: config_file.replication_controller.deploy_strategy)
    end
  end
end
