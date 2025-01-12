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

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # Do not check RichText.
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'Frontend::RichText',
            Value => 0,
        );

        # Create and log in test user.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'users', 'itsm-service' ],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # Get test user ID.
        my $TestUserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $TestUserLogin,
        );

        # Create two test tickets.
        my @TicketIDs;
        my @TicketNumbers;
        my $TicketTitle = "Selenium Ticket" . $Helper->GetRandomID();
        for my $Ticket ( 1 .. 2 ) {
            my $TicketNumber = $TicketObject->TicketCreateNumber();
            my $TicketID     = $TicketObject->TicketCreate(
                TN           => $TicketNumber,
                Title        => $TicketTitle,
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
            push @TicketIDs,     $TicketID;
            push @TicketNumbers, $TicketNumber;
        }

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # Navigate to zoom view of first created test ticket.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketIDs[0]");

        # Wait until a link has loaded to the element.
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('a[href*=\"Action=AgentTicketClose;TicketID=$TicketIDs[0]\"]').length"
        );

        # Set review required via Close menu.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentTicketClose;TicketID=$TicketIDs[0]' )]")->click();

        # Switch to Close window.
        $Selenium->WaitFor( WindowCount => 2 );
        my $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $("#DynamicField_ITSMReviewRequired").length && $("#Subject").length'
        );

        # Close ticket and set review required.
        $Selenium->execute_script(
            "\$('#DynamicField_ITSMReviewRequired').val('Yes').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( "#Subject",  'css' )->send_keys('Selenium Test');
        $Selenium->find_element( "#RichText", 'css' )->send_keys('ReviewRequired');
        $Selenium->find_element("//button[\@type='submit']")->click();

        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        # Navigate to zoom view of second created test ticket.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentTicketZoom;TicketID=$TicketIDs[1]");

        # Wait until a link has loaded to the element.
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('a[href*=\"Action=AgentTicketClose;TicketID=$TicketIDs[1]\"]').length"
        );

        # Set review required via Close menu.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentTicketClose;TicketID=$TicketIDs[1]' )]")->click();

        $Selenium->WaitFor( WindowCount => 2 );
        $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor(
            JavaScript =>
                'return typeof($) === "function" && $("#DynamicField_ITSMReviewRequired").length && $("#Subject").length'
        );

        # Close ticket and set review required.
        $Selenium->execute_script(
            "\$('#DynamicField_ITSMReviewRequired').val('Yes').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( "#Subject",  'css' )->send_keys('Selenium Test');
        $Selenium->find_element( "#RichText", 'css' )->send_keys('ReviewRequired');
        $Selenium->find_element("//button[\@type='submit']")->click();

        $Selenium->WaitFor( WindowCount => 1 );
        $Selenium->switch_to_window( $Handles->[0] );

        $Selenium->VerifiedRefresh();
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $("#GlobalSearchNav").length' );

        # Click on search.
        $Selenium->find_element( "#GlobalSearchNav", 'css' )->click();
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#Attribute').length && \$('#SearchFormSubmit').length"
        );

        # Select review required and title search field.
        my $ReviewRequiredID = "Search_DynamicField_ITSMReviewRequired";
        $Selenium->execute_script(
            "\$('#Attribute').val('$ReviewRequiredID').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#SearchInsert #$ReviewRequiredID').length"
        );

        $Selenium->execute_script("\$('#Attribute').val('Title').trigger('redraw.InputField').trigger('change');");
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('#SearchInsert input[name=\"Title\"]').length"
        );

        # Search tickets by review required and ticket title.
        $Selenium->find_element("//input[\@name='Title']")->send_keys($TicketTitle);
        $Selenium->execute_script(
            "\$('#$ReviewRequiredID').val('Yes').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->execute_script('$("#SearchFormSubmit").click();');

        $Selenium->WaitFor( JavaScript => "return typeof(\$) === 'function' && !\$('.Dialog.Modal').length" );
        $Selenium->WaitFor(
            JavaScript =>
                "return typeof(\$) === 'function' && \$('a:contains(\"$TicketNumbers[0]\")').length && \$('a:contains(\"$TicketNumbers[1]\")').length"
        );
        sleep 2;

        # Check for test created tickets on screen.
        for my $TicketNumber (@TicketNumbers) {
            $Self->True(
                $Selenium->execute_script("return \$('a:contains(\"$TicketNumber\")').length"),
                "Test ticket number $TicketNumber - found",
            ) || die;
        }

        # Delete created test tickets.
        for my $TicketDelete (@TicketIDs) {
            my $Success = $TicketObject->TicketDelete(
                TicketID => $TicketDelete,
                UserID   => $TestUserID,
            );
            $Self->True(
                $Success,
                "Ticket is deleted - ID $TicketDelete"
            );
        }

        # Make sure the cache is correct.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => 'Ticket',
        );
    }
);

1;
