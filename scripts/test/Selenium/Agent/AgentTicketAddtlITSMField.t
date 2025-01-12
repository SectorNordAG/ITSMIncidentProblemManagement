# --
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2022 Znuny GmbH, https://znuny.org/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # create and log in test user
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'itsm-service' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get test user ID
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # create test tickets
        my $TicketID = $TicketObject->TicketCreate(
            Title        => "Selenium Test Ticket",
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'new',
            CustomerID   => 'SeleniumCustomer',
            CustomerUser => "SeleniumCustomer\@localhost.com",
            OwnerID      => $TestUserID,
            UserID       => $TestUserID,
        );
        $Self->True(
            $TicketID,
            "Ticket is created - ID $TicketID",
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to zoom view of created test ticket
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketID");

        # click 'Additional ITSM Fields' and switch window
        $Selenium->find_element("//a[contains(\@href, 'Action=AgentTicketAddtlITSMField;TicketID=$TicketID' )]")
            ->click();

        $Selenium->WaitFor( WindowCount => 2 );
        my $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # wait until page has loaded, if necessary
        $Selenium->WaitFor(
            JavaScript => 'return typeof($) === "function" && $("#DynamicField_ITSMRepairStartTimeUsed").length'
        );

        # check screen
        for my $ID (
            qw( RepairStartTimeUsed RecoveryStartTimeUsed DueDateUsed)
            )
        {
            my $Element = $Selenium->find_element( "#DynamicField_ITSM$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # change title and add repair, recovery and due dates
        $Selenium->find_element( "#Title", 'css' )->clear();
        $Selenium->find_element( "#Title", 'css' )->send_keys("Selenium ITSM Fields Ticket");
        $Selenium->find_element( "#DynamicField_ITSMRepairStartTimeUsed",   'css' )->click();
        $Selenium->find_element( "#DynamicField_ITSMRecoveryStartTimeUsed", 'css' )->click();
        $Selenium->find_element("//button[\@type='submit']")->click();

        # switch back to zoom view
        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        # wait until page has loaded, if necessary
        $Selenium->WaitFor(
            JavaScript => 'return typeof($) === "function" && $(".Cluster").length'
        );

        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketHistory;TicketID=$TicketID");

        # wait until page has loaded, if necessary
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $(".CancelClosePopup").length' );

        # check for TicketDynamicFieldUpdates
        for my $UpdateText (qw(RepairStartTime RecoveryStartTime DueDate)) {
            $Self->True(
                index( $Selenium->get_page_source(), "Changed dynamic field ITSM$UpdateText" ) > -1,
                "DynamicFieldUpdate $UpdateText - found",
            );
        }

        # delete created test tickets
        my $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => $TestUserID,
        );
        $Self->True(
            $Success,
            "Ticket is deleted - ID $TicketID"
        );

        # make sure the cache is correct
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Ticket',
        );
    }
);

1;
