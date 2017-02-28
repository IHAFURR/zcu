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
my $password = "pass-for-student-2017";

# Settig a COS for new users
# by default "student"
my $newUsersCOS = "student";

# script beggins there, so be care and make editing with caution
my ($sec, $min, $hour, $day, $month, $year) = gmtime(time);
$year += 1900;
$month += 1;
$hour += 2;

# Date variable for error and log files;
my $errDate = "$day$month$year";

# we will use subs for main actions in the script
my $logFile = "log-$errDate-main.dat";
my $errorFileExist = "error-users-exist-$errDate-main.csv";
my $errorFileDublicateName = "error-mail-dublicate-$errDate-main.csv";
my $errorFileAdded = "error-mail-created-$errDate-main.csv";
my $errorFileCantAddUsers = "error-not-added-$errDate-main.csv";

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

    if (!$uid || !$name)
    {
        printLOG('Cant get mail or uid, check if delimiter = \";\"');
        exit();
    }

    if (checkUID($uid, $name))
    {
        open(my $exist, ">>$errorFileExist") or die "Cant open file $errorFileExist, $!\n";
        print $exist "$line\n";
        $usersExist++;
    }
    else
    {
        printLOG("Trying create new user $name $uid");
        $zimbraEmail = createNewMail($name);

        if (!$zimbraEmail)
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
                if (checkUserUIDZimbra($zimbraEmail) == $uid)
                {
                    printLOG("Such user, $zimbraEmail, $uid, already exist, skipping");
                    open(my $exist, ">>$errorFileExist") or die "Cant open file $errorFileExist, $!\n";
                    print $exist "$line\n";
                    $usersExist++;
                }
                else
                {
                    printLOG("Creating user with dublicated mail");
                    $zimbraEmail = "";
                    $zimbraEmail = createNewMail($name, 1);

                    if (!$zimbraEmail)
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

                            if (checkUserUIDZimbra($zimbraEmail) == $uid)
                            {
                                printLOG("Such user, $zimbraEmail, $uid, already exist, skipping");
                                open(my $exist, ">>$errorFileExist") or die "Cant open file $errorFileExist, $!\n";
                                print $exist "$line\n";
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
                                open(my $created, ">>$errorFileAdded") or die "Cant open file $errorFileAdded, $!\n";
                                print $created "$zimbraEmail;$line\n";
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
                    open(my $tmp, ">>$errorFileAdded") or die "Cant open file $errorFileAdded, $!\n";
                    print $tmp "$zimbraEmail;$line\n";
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

    if (!$temp)
    {
        printLOG("Can't find such COS or it does not exist,
                you should update users latter and add them to COS");
        return ;
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
        return 1;
    }
    else
    {
        printLOG("Cant find $checkUID, $checkName user in mailUIDHash");
        return ;
    }
}

sub checkIfUserExist
{
    my $tmpEmail = shift;
    my @tmpArr = ();
    my $answ = "";
    $tmpEmail = trim($tmpEmail);
    my ($write, $read, $error) = ('', '', '');
    my $pid = open3($write, $read, $error,
        "su - zimbra -c \"ldapsearch -H $LDAPURL -w $LDAPPASS -D uid=zimbra,cn=admins,cn=zimbra -x -LLL \'(&(mail=$tmpEmail))\' \"");
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

    foreach(@tmpArr) {
        if (index($_, "uid") != - 1) {
            $answ = $_;
            $answ =~ s/\n//g;
            $answ =~ s/uid: //g;
        }
    }

    if (!$answ)
    {
        printLOG("User, $tmpEmail, does not exist");
        waitpid($pid, 0);
        return;
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
        "su - zimbra -c \"ldapsearch -H $LDAPURL -w $LDAPPASS -D uid=zimbra,cn=admins,cn=zimbra -x -LLL \'(&(mail=$tmpEmail))\' facsimileTelephoneNumber\" |grep facsimileTelephoneNumber ");
    my $selread = IO::Select->new();
    my $selerror = IO::Select->new();
    my ($print_err, $print_answer) = ('', '');
    $selread->add($read);
    $selerror->add($error);


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

    if (!$answ || ($answ !~ /^[0-9]+$/))
    {
        printLOG("User, $tmpEmail, does not have uid - facsimileTelephoneNumber: $answ");
        waitpid($pid, 0);
        return;
    }
    else
    {
        printLOG("User, $tmpEmail, has - facsimileTelephoneNumber: $answ");
        waitpid($pid, 0);
        return trim($answ);
    }
}

sub createNewUser
{
    my $tmpuid = shift;
    my $tmpMail = shift;
    my $tmpFullName = shift;
    my $tmpPassword = $password;

    if (!$tmpPassword)
    {
        $tmpPassword = "password-default-17";
    }

    $tmpFullName = trim($tmpFullName);
    $tmpMail = trim($tmpMail);
    my ($first, $last, $middle) = split(/ /, $tmpFullName);
    printLOG("Creating user with email $tmpMail and name $tmpFullName");

    open(my $tmp, ">/tmp/tempzimbra") or die "Cant open /tmp/tempfile, $!\n";

    if (!$tmpuid || !$tmpMail)
    {
        printLOG("Cant create user: $tmpMail with uid: $tmpuid");
        exit();
    }

    print $tmp "ca $tmpMail $tmpPassword\n";
    print $tmp "ma $tmpMail facsimileTelephoneNumber \"$tmpuid\"\n";

    if (!$studentCOS)
    {
        $studentCOS = "default";
    }
    print $tmp "ma $tmpMail zimbraCOSId \"$studentCOS\"\n";
    print $tmp "ma $tmpMail givenName \"$last\"\n";
    print $tmp "ma $tmpMail sn \"$first\"\n";

    if ($middle)
    {
        print $tmp "ma $tmpMail initials \"$middle\"\n";
    }
    print $tmp "ma $tmpMail displayName \"$first $last\"\n";
    print $tmp "ma $tmpMail company \"$university\"\n";
    print $tmp "ma $tmpMail l \"$city\"\n";
    print $tmp "ma $tmpMail co \"$country\"\n";
    print $tmp "ma $tmpMail title \"$title\"\n";
    # you can add your own field

    my $exec = `su - zimbra -c 'zmprov -f /tmp/tempzimbra'`;
}

sub createNewMail
{
    my $tmpFullName = shift;
    my $dublicate = shift; #if 0 then first.last else first.last.middle[0];
    my $tmpFirst = "";
    my $tmpLast = "";
    my $tmpMiddle = "";

    ($tmpFirst, $tmpLast, $tmpMiddle) = split(/ /, $tmpFullName);

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

    if (!$dublicate)
    {

        if (!$tr_last || !$tr_first)
        {
            $tr_mail = "";
        }
        else
        {
            $tr_last =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;
            $tr_first =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;

            $tr_mail = "\L$tr_first\.$tr_last\@$domain";
        }
    }
    else
    {

        if (!$tr_first || !$tr_last || !$tr_middle)
        {
            $tr_mail = "";
        }
        else
        {
            $tr_last =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;
            $tr_first =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;
            $tr_middle =~ s/[\$\#\@\~\!\&\*\(\)\[\]\;\.\,\:\^\ \-\+\=\_\|\{\}\?\%\№\’\"\“\”\'\`\\\/]+//g;

            # add first char of the middle name to the mail
            $tr_middle = substr $tr_middle, 0, 1;
            $tr_mail = "\L$tr_first\.$tr_last\.$tr_middle\@$domain";
        }
    }

    if (!$tr_mail)
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
