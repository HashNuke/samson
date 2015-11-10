Build.class_eval do

  has_many :kubernetes_releases, class_name: 'Kubernetes::Release'

  def project_name
    @project_name ||= project.name.parameterize('-')
  end

  def import_kubernetes_roles
    # TODO : Build -> KubernetesRoles association
    project.roles.destroy_all

    config_files = project.repository.directory_contents(git_sha, path: 'kubernetes', ).select { |file|
      file.ends_with?('.yml', '.yaml', '.json')
    }

    config_files.map do |file|
      file_contents = project.repository.file_contents(git_sha, file)
      config_file = Kubernetes::RoleConfigFile.new(file_contents, file)

      # TODO : Build -> KubernetesRoles association
      role = project.roles.build(
        project: project,
        name: config_file.replication_controller.labels[:role],
        config_file: file,
        service_name: config_file.service.name,
        ram: config_file.replication_controller.pod_template.container.ram,
        cpu: config_file.replication_controller.pod_template.container.cpu,
        replicas: config_file.replication_controller.replicas,
        deploy_strategy: config_file.replication_controller.deploy_strategy)
      role.save!
      role
    end
  end
end
