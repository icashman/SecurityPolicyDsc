<#
.Synopsis
   Template for creating DSC Resource Unit Tests
.DESCRIPTION
   To Use:
     1. Copy to \Tests\Unit\ folder and rename MSFT_x<ResourceName>.tests.ps1
     2. Customize TODO sections.

.NOTES
   Code in HEADER and FOOTER regions are standard and may be moved into DSCResource.Tools in
   Future and therefore should not be altered if possible.
#>

$Global:DSCModuleName    = 'SeceditDSC'
$Global:DSCResourceName  = 'MSFT_UserRightsAssignment'


#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module .\DSCResource.Tests\TestHelper.psm1 -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Unit 
#endregion

# Begin Testing
try
{

    #region Pester Tests
    InModuleScope $Global:DSCResourceName {

        #region Pester Test Initialization

            $testUSR = [PSObject]@{
                Policy = 'Access_Credential_Manager_as_a_trusted_caller'                
                Identity = 'contoso\TestUser1'
            }

            $mockUSR = [PSObject]@{
                Policy = 'SeTrustedCredManAccessPrivilege'
                Identity = 'contoso\testUser1','contoso\TestUser2'
                PolicyFriendlyName = $testUSR.Policy
            }

            $mockGetTargetResult = [PSObject] @{
                Policy = $testUSR.Policy
                Identity = 'contoso\TestUser2'
                ActualIdentity = 'contoso\TestUser1'
            }
        #endregion

        #region Function Get-TargetResource
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {        
               
            Context 'Testing policy details' {

                Mock Get-USRPolicy -MockWith {$mockUSR}

                It 'Should return expected properties' {
                    
                    $result = Get-TargetResource @testUSR

                    $result.Policy | Should Be $testUSR.Policy
                    $result.Identity | Should Be $testUSR.Identity
                    $result.ActualIdentity | Should Be $mockUSR.Identity
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -CommandName Get-USRPolicy -Exactly 1
                }
            }              
        }
        #endregion

        #region Function Test-TargetResource
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
            Context 'Identity does exist' {
                Mock Get-USRPolicy -MockWith {$mockUSR}

                It 'Should return true' {
                    $testResult = Test-TargetResource @testUSR

                    $testResult | Should Be $true
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Get-USRPolicy -Exactly 1
                }
            }

            Context 'Identity does not exist' {
                $mockFalse = $mockUSR.Clone()
                $mockFalse.Identity = 'contoso\NoUser'

                Mock Get-USRPolicy -MockWith {$mockFalse}

                It 'Should return false' {
                    $testResult = Test-TargetResource @testUSR

                    $testResult | Should Be $false
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Get-USRPolicy -Exactly 1
                }
            }
        }
        #endregion
        #region Function Set-TargetResource
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {

            Context 'Identity does not exist but should' {                
                Mock Invoke-Secedit
                Mock Out-UserRightsInf
                Mock Test-TargetResource -MockWith {$true}
                Mock Get-Content

                It 'Should not throw' {
                    {Set-TargetResource @testUSR} | Should Not Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Invoke-Secedit      -Exactly 1
                    Assert-MockCalled -CommandName Test-TargetResource -Exactly 1
                    Assert-MockCalled -CommandName Out-UserRightsInf   -Exactly 1
                    Assert-MockCalled -CommandName Get-Content         -Exactly 0
                }
            }

            Context 'Identity was not configured successfully' {
                Mock Invoke-Secedit
                Mock Out-UserRightsInf
                Mock Test-TargetResource -MockWith {$false}
                Mock Get-Content -MockWith {'Error updating USR'}

                It 'Should throw' {
                    {Set-TargetResource @testUSR} | Should Throw
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Invoke-Secedit      -Exactly 1
                    Assert-MockCalled -CommandName Test-TargetResource -Exactly 1
                    Assert-MockCalled -CommandName Out-UserRightsInf   -Exactly 1
                    Assert-MockCalled -CommandName Get-Content         -Exactly 1
                }
            }

            Context 'Idenity is NULL (Remove all identites from policy)' {
            Mock Invoke-Secedit
                Mock Out-UserRightsInf
                Mock Get-Content
                Mock Test-TargetResource -MockWith {$true}

                It 'Identity is NULL should remove all' {
                    $nullUSR = $testUSR.Clone()
                    $nullUSR.Identity = 'NULL'

                    {Set-TargetResource @nullUSR} | Should Not Throw                    
                }

                It 'Should call expected mocks' {
                    Assert-MockCalled -CommandName Invoke-Secedit      -Exactly 1
                    Assert-MockCalled -CommandName Test-TargetResource -Exactly 1
                    Assert-MockCalled -CommandName Out-UserRightsInf   -Exactly 1
                    Assert-MockCalled -CommandName Get-Content         -Exactly 0
                }
            } 
        }
        #endregion
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}