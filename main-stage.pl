#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';

use Time::Local;
use Time::localtime;
use IO::Select;
use IPC::Open3;
use locale;

use Lingua::Translit;


# URL and Password for ldapsearch in zimbra, we can
# still use "zmpov" but it take more time.
my $LDAPURL = "";
my $LDAPPASS = "";
my $domain = "";

# File required for script
my $edboFile = "";
my $uidmailFile = "";

my $university = "";
my $title = "";
my $country = "";
my $city = "";
my $password = "";

# Settig a COS for new users
# by default "student"
my $newUsersCOS = "";

# script beggins there, so be care and make editing with caution
my ($sec, $min, $hour, $day, $month, $year) = gmtime(time);
$year += 1900;
$month += 1;
$hour += 2;

# Date variable for error and log files;
my $errDate = "$day$month$year";

# we will use subs for main actions in the script
my $logFile = "log-$errDate-main.dat";
my $errorFileExist = "error-users-exist-$errDate-main.dat";
my $errorFileDublicateName = "error-mail-dublicate-$errDate-main.dat";
my $errorFileCantAddUsers = "error-not-added-$errDate-main.dat";

my $usersExist = 0;
my $usersAdded = 0;
my $usersAddedDublicate = 0;
my $usersCantBeAdded = 0;

# needed for checking if users exists with a different mail
# and for Logs
my %mailUIDHash;
my $studentCOS;

################   STARTING   ################
printLOG("################   STARTING   ################");
printLOG("##########   $day/$month/$year  $hour:$min:$sec   ##########");

$studentCOS = getStudentCOS($newUsersCOS);
%mailUIDHash = createMailUIDHash();

open(my $edbo,  "$edboFile") or die "Can open file $edboFile, $!\n";
    while (my $line = <$edbo>)
    {
        chomp($line);
        my $zimbraEmail = "";
        my ($uid, $name) = split(/\;/, $line);

        if (checkUID($uid, $name))
        {
            open(my $exist, ">>$errorFileExist") or die "Cant open file $errorFileExist, $!\n";
                print $exist "$line";
            $usersExist++;
        }
        else
        {
            printLOG("Trying create new user");
            $zimbraEmail = createNewMail($name, 0);

            if ($zimbraEmail eq "")
            {
                printLOG("Cant create mail for $name, adding to $errorFileCantAddUsers");
                open(my $error, ">>$errorFileCantAddUsers");
                    print $error "$line\n";
                $usersCantBeAdded++;
            }
            else
            {
                if (checkIfUserExist($zimbraEmail))
                {
                    printLOG("Such mail already exist, checking uid");
                    if (checkUserUIDZimbra($zimbraEmail) eq $uid)
                    {
                        printLOG("Such user, $zimbraEmail, $uid, already exist, skipping");
                        open(my $exist, ">>$errorFileExist") or die "Cant open file $errorFileExist, $!\n";
                            print $exist "$line";
                        $usersExist++;
                    }
                    else
                    {
                        printLOG("Creating user with dublicated mail");
                        $zimbraEmail = "";
                        $zimbraEmail = createNewMail($name, 1);

                        if ($zimbraEmail eq "")
                        {
                            printLOG("Cant create mail for $name, adding to $errorFileCantAddUsers");
                            open(my $error, ">>$errorFileCantAddUsers");
                                print $error "$line\n";
                            $usersCantBeAdded++;
                        }
                        else
                        {
                            if (checkIfUserExist($zimbraEmail))
                            {
                                printLOG("Such dublicated mail already exist, checking uid");

                                if (checkUserUIDZimbra($zimbraEmail) eq $uid)
                                {
                                    printLOG("Such user, $zimbraEmail, $uid, already exist, skipping");
                                    open(my $exist, ">>$errorFileExist") or die "Cant open file $errorFileExist, $!\n";
                                        print $exist "$line";
                                    $usersExist++;
                                }
                                else
                                {
                                    printLOG("Cant create user $zimbraEmail");
                                    open(my $tmp, ">>$errorFileCantAddUsers") or die "Cant open file $errorFileCantAddUsers, $!\n";
                                        print $tmp "$line\n";
                                    $usersCantBeAdded++;
                                }
                            }
                            else
                            {
                                createNewUser($uid, $zimbraEmail, $name);

                                if (checkIfUserExist($zimbraEmail))
                                {
                                    printLOG("User, $name, was created with mail $zimbraEmail");
                                    open(my $tmp, ">>$errorFileDublicateName") or die "Cant open file $errorFileDublicateName, $!\n";
                                        print $tmp "$zimbraEmail;$line\n";
                                    $usersAddedDublicate++;
                                }
                                else
                                {
                                    printLOG("Cant create user $zimbraEmail");
                                    open(my $tmp, ">>$errorFileCantAddUsers") or die "Cant open file $errorFileCantAddUsers, $!\n";
                                        print $tmp "$line\n";
                                    $usersCantBeAdded++;
                                }
                            }
                        }
                    }
                }
                else
                {
                    createNewUser($uid, $zimbraEmail, $name);

                    if (checkIfUserExist($zimbraEmail))
                    {
                        printLOG("User, $name, was created with mail $zimbraEmail");
                        $usersAdded++;
                    }
                    else
                    {
                        printLOG("Cant create user $zimbraEmail");
                        open(my $tmp, ">>$errorFileCantAddUsers") or die "Cant open file $errorFileCantAddUsers, $!\n";
                            print $tmp "$line\n";
                        $usersCantBeAdded++;
                    }
                }
            }
        }
    }

my $creted = $usersAdded + $usersAddedDublicate;
my $amount = $usersExist + $usersAdded + $usersAddedDublicate + $usersCantBeAdded;

printLOG("##################   END   ##################\n".
         "Users exist:      $usersExist\n".
         "Users not added:  $usersCantBeAdded\n".
         "Users created:    $creted\n".
         "Users dublicate:  $usersAddedDublicate\n".
         "Amount:           $amount\n\n");

##################   SUBS   ##################

# sub for logging
sub printLOG
{
    my $str = shift;

    open(my $log, ">>$logFile") or die "Cant open $logFile, $!\n";
        print $log "LOG: $str\n";
}
# delete all spaces before and after string
sub trim
{
    my $str = shift;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub getStudentCOS
{
    my $cos = shift;
    my $temp = `su - zimbra -c 'zmprov gc $cos |grep zimbraId:'`;
    $temp =~ s/zimbraId:\s*|\s*$//g;

    if ($temp eq "")
    {
        printLOG("Can't find such COS or it does not exist,
                you should update users latter and add them to COS");
        return "";
    }
    return $temp;
}

# Require a file with uid;mail
sub createMailUIDHash {
    my %tempHash;

    my $amountOfUID = 0;
    my $amountOFDuplicated = 0;

    open (my $tmp, "$uidmailFile") or die "Cant open $uidmailFile, $!\n";
        while (my $line = <$tmp>)
        {
            chomp($line);
            my ($uid, $mail) = split(/\;/, $line);
            $uid = trim($uid);
            $mail = trim($mail);
            if (exists($tempHash{$uid}))
            {
                printLOG("Such user already exist:  $uid $tempHash{$uid} duplicated mail $mail");
                $amountOfUID++;
                $amountOFDuplicated++;
            }
            else
            {
                $tempHash{$uid} = $mail;
                $amountOfUID++;
            }
        }
    printLOG("##########  createMailUIDHash  ########");
    printLOG("Hash created: $amountOfUID,  Users skiped: $amountOFDuplicated");
    return %tempHash;
}

sub checkUID
{
    my $checkUID = shift;
    my $checkName = shift;
    $checkUID = trim($checkUID);
    $checkName = trim($checkName);

    if (exists($mailUIDHash{$checkUID}))
    {
        printLOG("User already exist with email: $mailUIDHash{$checkUID} and should be skipped");
        open(my $tmpExist, ">>$errorFileExist") or die "Cant open file $errorFileExist, $!\n";
            print $tmpExist "$checkName;$checkUID;$mailUIDHash{$checkUID}\n";
        return 1;
    }
    else
    {
        printLOG("Cant find such user in mailUIDHash");
        return 0;
    }
}

sub checkIfUserExist
{
    my $tmpEmail = shift;
    my @tmpArr;
    $tmpEmail = trim($tmpEmail);
    my ($write, $read, $error) = ('', '', '');
    my $pid = open3($write, $read, $error,
        "su - zimbra -c \"ldapsearch -H $LDAPURL -w $LDAPPASS -D uid=zimbra,cn=admins,cn=zimbra -x -LLL \'(&(mail=$tmpEmail))\' facsimileTelephoneNumber\" |grep facsimileTelephoneNumber ");
    my $selread = IO::Select->new();
    my $selerror = IO::Select->new();
    my ($print_err, $print_answer) = ('', '');
    $selread->add($read);
    $selerror->add($error);

    if ($selerror->can_read())
    {
        sysread($error, $print_err, 4096);
        printLOG("Cant check if user exist, error ocured: \n$print_err");
        waitpid($pid, 0);
        exit();
    }

    while (sysread($read, $print_answer, 4096)) {
        if ($selread->can_read()) {
            push(@tmpArr, $print_answer);
        }
    }

    if (!(length @tmpArr))
    {
        printLOG("User, $tmpEmail, does not exist");
        waitpid($pid, 0);
        return 0;
    }
    else
    {
        printLOG("User, $tmpEmail, already exist");
        waitpid($pid, 0);
        return 1;
    }
}

sub checkUserUIDZimbra
{
    my $tmpEmail = shift;
    $tmpEmail = trim($tmpEmail);
    my @tmpArr;
    my $answ = "";
    my ($write, $read, $error) = ('', '', '');
    my $pid = open3($write, $read, $error,
        "su - zimbra -c \"ldapsearch -H $LDAPURL -w $LDAPPASS -D uid=zimbra,cn=admins,cn=zimbra -x -LLL \'(&(mail=$tmpEmail))\'\"");
    my $selread = IO::Select->new();
    my $selerror = IO::Select->new();
    my ($print_err, $print_answer) = ('', '');
    $selread->add($read);
    $selerror->add($error);

#    if ($selread->can_read())
#    {
#        printLOG("Trying get user uid from zimbra");
#    }

    if ($selerror->can_read())
    {
        sysread($error, $print_err, 4096);
        printLOG("Cant get user uid from zimbra, error ocured: \n$print_err");
        waitpid($pid, 0);
        exit();
    }

    while (sysread($read, $print_answer, 4096)) {
        if ($selread->can_read()) {
            push(@tmpArr, $print_answer);
        }
    }

    foreach(@tmpArr) {
        if (index($_, "facsimileTelephoneNumber") != - 1) {
            $answ = $_;
            $answ =~ s/\n//g;
            $answ =~ s/facsimileTelephoneNumber: //g;
        }
    }

    if (!$answ)
    {
        printLOG("User, $tmpEmail, does not have uid - facsimileTelephoneNumber: $answ");
        waitpid($pid, 0);
        return 0;
    }
    else
    {
        printLOG("User, $tmpEmail, has - facsimileTelephoneNumber: $answ");
        waitpid($pid, 0);
        return trim($print_answer);
    }
}

sub createNewUser
{
    my $tmpuid = shift;
    my $tmpMail = shift;
    my $tmpFullName = shift;
    my $tmpPassword = $password;

    if ($tmpPassword eq "")
    {
        $tmpPassword = "password-default-17";
    }

    $tmpFullName = trim($tmpFullName);
    $tmpMail = trim($tmpMail);
    my ($first, $last, $middle) = split(/ /, $tmpFullName);
    printLOG("Creating user with email $tmpMail and name $tmpFullName");

    open(my $tmp, ">/tmp/tempzimbra") or die "Cant open /tmp/tempfile, $!\n";
        print $tmp "ca $tmpMail $tmpPassword\n";
        print $tmp "ma $tmpMail facsimileTelephoneNumber \"$tmpuid\"\n";
        print $tmp "ma $tmpMail zimbraCOSId \"$studentCOS\"\n";
        print $tmp "ma $tmpMail givenName \"$last\"\n";
        print $tmp "ma $tmpMail sn \"$first\"\n";
        print $tmp "ma $tmpMail initials \"$middle\"\n";
        print $tmp "ma $tmpMail displayName \"$first $last\"\n";
        print $tmp "ma $tmpMail company \"$university\"\n";
        print $tmp "ma $tmpMail l \"$city\"\n";
        print $tmp "ma $tmpMail co \"$country\"\n";
        print $tmp "ma $tmpMail title \"$title\"\n";

    # check the difference beetwen this 2 lines

#    system("su - zimbra -c 'zmprov - f /tmp/tempzimbra'");
#    if ($? == -1)
#    {
#        printLOG("Cant create user: $tmpMail");
#    }
#    else
#    {
#        printLOG("User was created: $tmpMail");
#    }
    my $exec = `su - zimbra -c 'zmprov - f /tmp/tempzimbra'`;
}

sub createNewMail
{
    my $tmpFullName = shift;
    my $dublicate = shift; #if 0 then first.last else first.last.middle[0];

    my ($tmpFirst, $tmpLast, $tmpMiddle) = split(/ /, $tmpFullName);
    $tmpFirst = trim($tmpFirst); #surname
    $tmpLast = trim($tmpLast);   #name
    $tmpMiddle = trim($tmpMiddle);
    
    my $tr = new Lingua::Translit("GOST 7.79 UKR");
    my $tr_first;
    my $tr_last;
    my $tr_middle;
    my $tr_mail;

    if ($tr->can_reverse())
    {
        $tr_first = $tr->translit($tmpFirst);
        $tr_last = $tr->translit($tmpLast);
        $tr_middle = $tr->translit($tmpMiddle);
    }
    else
    {
        printLOG("Cant translit into English, check if Lingua::Translitt installed");
        exit();
    }

    $tr_last =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;
    $tr_first =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;
    $tr_middle =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;

    if ($dublicate eq "0")
    {
        if (($tr_last eq "") || ($tr_first eq ""))
        {
            $tr_mail = "";
        }
        else
        {
            $tr_mail = "\L$tr_first\.$tr_last\@$domain";
        }
    }
    else
    {
        # add first char of middle name to tha mail
        $tr_middle = substr $tr_middle, 0, 1;

        if (($tr_first eq "") || ($tr_last eq "") || ($tr_middle eq ""))
        {
            $tr_mail = "";
        }
        else
        {
            $tr_mail = "\L$tr_first\.$tr_last\.$tr_middle\@$domain";
        }
    }

    if ($tr_mail eq "")
    {
        printLOG("Cant create mail for new user: $tmpFullName");
    }
    else
    {
        my $rexmail = qr/[a-z]([a-z.]*[a-z])?/;
        my $rexdomain = qr/[a-z0-9.-]+/;

        if ($tr_mail =~ /^$rexmail\@$rexdomain/)
        {
            return $tr_mail;
        }
    }

    return $tr_mail;
}
