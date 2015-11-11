(function() {
  'use strict';

  var module = angular.module('app.setup');

  /**
   * @ngdoc controller
   * @kind constructor
   * @name EditIndexCtrl
   * @description
   */
  module.controller('EditConstraintCtrl', ['$modalInstance', '$scope', 'ServerConfig', 'index', 'indexType', function ($modalInstance, $scope, ServerConfig, index, indexType) {
      $scope.indexType = indexType;
      $scope.index = index;
      $scope.save = function () {
        $modalInstance.close($scope.index);
      };
    }]);

  /**
   * @ngdoc dialog
   * @name newRangeIndexDialog
   * @kind function
   * @description A UI Bootstrap component that provides a modal dialog for
   * adding a range index to the application.
   */
  module.factory('EditConstraintDialog', [
    '$modal',
    function ($modal) {
      return function (constraint) {
        var indexValue,
            indexType;
        angular.forEach(index, function(val, keyName){
          if (keyName === 'geospatial-element-index' || keyName === 'geospatial-element-pair-index' || keyName === 'geospatial-element-attribute-pair-index') {
            indexType = keyName;
            indexValue = val;
          }
        });
        return $modal.open({
            templateUrl: 'app/setup/dialogs/editGeospatialIndex.html',
            controller: 'EditConstraintCtrl',
            size: 'lg',
            resolve: {
              index: function() {
                return indexValue;
              },
              indexType: function() {
                return indexType;
              }
            }
          }).result;
      };
    }
  ]);

}());
