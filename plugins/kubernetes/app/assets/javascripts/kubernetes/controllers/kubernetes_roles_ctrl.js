samson.controller('KubernetesRolesCtrl', function($scope, $stateParams, kubernetesService, kubernetesRoleFactory, notificationService) {
  $scope.project_id = $stateParams.project_id;

  $scope.refreshRoles = function(reference) {
    // Broadcast event to child controllers (i.e., the Git reference typeahead directive)
    $scope.$broadcast('gitReferenceSubmissionStart');

    kubernetesService.refreshRoles($scope.project_id, reference).then(
      function(data) {
        $scope.roles = data.map(function(item) {
          return kubernetesRoleFactory.build(item);
        });

        notificationService.success('Kubernetes Roles imported successfully from Git reference: ' + reference);
        $scope.$broadcast('gitReferenceSubmissionCompleted');
      },
      function(error) {
        notificationService.error(error);
        $scope.$broadcast('gitReferenceSubmissionCompleted');
      }
    );
  };

  function loadRoles() {
    kubernetesService.loadRoles($scope.project_id).then(function(data) {
        $scope.roles = data.map(function(item) {
          return kubernetesRoleFactory.build(item);
        });
      }
    );
  }

  loadRoles();
});


