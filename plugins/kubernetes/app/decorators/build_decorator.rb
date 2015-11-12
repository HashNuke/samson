Build.class_eval do

  has_many :kubernetes_releases, class_name: 'Kubernetes::Release'

  def project_name
    @project_name ||= project.name.parameterize('-')
  end

  def import_kubernetes_roles
    config_files = project.repository.directory_contents(git_sha, path: 'kubernetes', ).select { |file|
      file.ends_with?('.yml', '.yaml', '.json')
    }

    config_files.map do |file|
      file_contents = file_from_repo(file)
      config_file = Kubernetes::RoleConfigFile.new(file_contents, file)

      Kubernetes::Role.new(
        project: project,
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
