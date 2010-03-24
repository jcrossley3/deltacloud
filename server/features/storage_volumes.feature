Feature: Working with storage volumes
  In order to work with storage volumes

  Background:
    Given I want to get XML

  Scenario: I want to get list of all storage volumes
    Given I am authorized to list storage volumes
    When I follow storage volumes link in entry points
    Then I should see <STORAGE_VOLUME_COUNT> storage volume inside storage volumes
    And each link in storage volumes should point me to valid storage volume

  Scenario: I want to show storage volume details
    Given I am authorized to show storage volume '<STORAGE_VOLUME_ID>'
    When I request for '<STORAGE_VOLUME_ID>' storage volume
    Then I should get this storage volume
    And storage volume should have valid href parameter
    And storage volume should include id parameter
    And storage volume should include created parameter
    And storage volume should include state parameter
    And storage volume should include capacity parameter
    And storage volume should include device parameter

  Scenario: I want to get storage volume instance
    Given I am authorized to show storage volume '<STORAGE_VOLUME_ID>'
    When I request for '<STORAGE_VOLUME_ID>' storage volume
    Then I should get this storage volume
    And I could follow instance href attribute
    And this attribute should point me to valid instance

  Scenario: I want filter storage volumes by state
    Given I am authorized to list storage volumes
    When I want storage volumes with '<STORAGE_VOLUME_STATE>' state
    Then I should get only realms with state '<STORAGE_VOLUME_STATE>'