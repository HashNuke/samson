var samson = angular.module("samson", [
    'templates',
    'MessageCenterModule',
    'ui.router',
    'ngAnimate',
    'ngMaterial',
    'ngAria',
    'ui.bootstrap',
    'truncate'])
  .config(function($locationProvider) {
    $locationProvider.html5Mode({enabled: true, rewriteLinks: false, requireBase: false});
  });

var A = angular;

A.$ = A.element;
