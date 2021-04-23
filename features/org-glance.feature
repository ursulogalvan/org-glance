Feature: Do Some things
  In order to register views
  As a user
  I want to define view scopes

  Scenario: Run org-glance on specific org-mode file
    Given empty scope
    And file with contents
      """
      * Holland :Country:
      * Belgium :Country:
      * Georgia :Country:
      * Ukraine :Country:
      """
    Then I add the file to scope
    Then I should have 1 file in scope
