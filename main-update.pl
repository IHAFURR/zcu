#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Time::Local;
use Time::localtime;

# File required for script
my $edboFile = "10-users.csv";
my $uidmailFile = "UIDMAIL.csv";

# not implemented
#my $passUniversity = "HNTU";
my $university = "ХНТУ";
my $country = "UA";
my $city = "Херсон";
my $title = "студент";

my $groupPrefix = "HN";
my $groupSuffix = "16"; # will be added anfter "group_"

# script beggins there, so be care and make editing with caution
my ($sec, $min, $hour, $day, $month, $year) = gmtime(time);
$year += 1900;
$month += 1;
$hour += 2;

# Date variable for error and log files;
my $errDate = "$day$month$year";

# we will use subs for main actions in the script
my $logFile = "log-moodle-$errDate-main.dat";
my $groupsFile = "groups-$errDate-main.csv";

my $errorFileDublicateName = "moodle-mail-dublicate-$errDate-main.csv";
my $errorFileAdded = "moodle-mail-created-$errDate-main.csv";
my $errorFileCantAddUsers = "moodle-not-added-$errDate-main.csv";
my $cohortsFile = "$university-moodle-update-$errDate.csv";

my $usersExist = 0;
my $usersNotExist = 0;

my %mailUIDHash;
my %groups;

################   STARTING   ################
printLOG("################   STARTING   ################");
printLOG("##########   $day/$month/$year  $hour:$min:$sec   ##########");

%mailUIDHash = createMailUIDHash();

open(my $edbo, "$edboFile") or die "Cant open file $edboFile, $!\n";
    while (my $line = <$edbo>)
    {
        chomp($line);
        my $mail = "";
        my $pass = "";
        my ($uid, $name, $kafedr, $group) = split(/\;/, $line);

        if (!$uid || !$name)
        {
            printLOG("cant get uid or name from file");
            exit();
        }

        $mail = getMail($uid, $name);

        if ($mail)
        {
            my ($first, $last, $middle) = split(/ /, $name);
            my ($username, $dom) = split(/\@/, $mail);
            $pass = createPassword();

            updateZimbraInfo($mail, $pass, $name, $group, $kafedr);
            printLOG("User $uid, $mail, $name was updated");
            addGroup($uid, $group, $kafedr);
            printLOG("Group, $group, was added");
            addUserToGroup($mail, $name, $pass, $group, $kafedr);
            printLOG("User, $uid, $mail, $name, $group was added to groupfile");
            open(my $tmpAdd, ">>$errorFileAdded") or die "Cant open file $errorFileAdded, $!\n";
                print $tmpAdd "$username,$mail,$pass,$first,$last,$middle\n";
            $usersExist++;
        }
        else
        {
            printLOG("Cant find such uid in file with uid, check it please");
            $usersNotExist++;
            open(my $tmp, ">>$errorFileCantAddUsers") or die "Cant open file $errorFileCantAddUsers, $!\n";
                print $tmp "$line\n";
        }
    }

my $amount = $usersExist + $usersNotExist;

printLOG("##################   END   ##################\n\n".
    "Users exist:         $usersExist\n".
    "Users do not exist:  $usersNotExist\n".
    "Amount:              $amount\n\n");

##########################################
################   SUBS   ################
sub printLOG
{
    my $str = shift;
    open(my $log, ">>$logFile") or die "Cant open $logFile, $!\n";
        print $log "LOG: $str\n";
}

sub createPassword
{
    my $pwd;
    my $tmp;
    my ($part1, $part2, $part3, $part4) = ("", "", "", "");
    my @char = ('!', '@', '#', '$');
    my @upchar = ('A'..'Z');
    my @lcchar = ('a'..'z');
    my @numb = (0..9);

    for (my $k = 0 ;$k < 1; $k++)
    {
        $part1 .= $lcchar[rand(scalar(@lcchar))];
    }

    for (my $k = 0 ;$k < 3; $k++)
    {
        $part2 .= $upchar[rand(scalar(@upchar))];
    }

    for (my $k = 0 ;$k < 2; $k++)
    {
        $part3 .= $char[rand(scalar(@char))].$numb[rand(scalar(@numb))];
    }

    for (my $k = 0 ;$k < 2; $k++)
    {
        $part4 .= $lcchar[rand(scalar(@lcchar))];
    }

    $tmp = int(rand(4));

    if ($tmp == 0)
    {
        $pwd = "$part3$part2$part1$part4";
    }

    if ($tmp == 1)
    {
        $pwd = "$part2$part3$part4$part1";
    }

    if ($tmp == 2)
    {
        $pwd = "$part1$part4$part2$part3";
    }

    if ($tmp == 3)
    {
        $pwd = "$part4$part1$part3$part2";
    }

    if (!$pwd)
    {
        $pwd = "$part4$part1$part3$part2";
    }

    return $pwd;
}

sub trim
{
    my $str = shift;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

# Require a file with uid;mail
sub createMailUIDHash {
    my %tempHash;

    my $amountOfUID = 0;
    my $amountOFDuplicated = 0;

    printLOG("Dublicated emails will be skipped, you should delete them from zimbra
     and check if they exist in the moodle, if yes, fix errors or delete such users
     and make update again");

    open (my $tmp, "$uidmailFile") or die "Cant open $uidmailFile, $!\n";
    while (my $line = <$tmp>)
    {
        chomp($line);
        my ($uid, $mail) = split(/\;/, $line);
        $uid = trim($uid);
        $mail = trim($mail);
        if (exists($tempHash{$uid}))
        {
            printLOG("Such user already exist:  $uid $tempHash{$uid} duplicated mail $mail delete some of them if it is not alias");
            open(my $tmpErr, ">>$errorFileDublicateName") or die "Cant open file $errorFileDublicateName, $!\n";
                print $tmpErr "UID: $uid have mails: $mail, $tempHash{$uid}\n";
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

sub getMail
{
    my $checkUID = shift;
    my $checkName = shift;
    $checkUID = trim($checkUID);
    $checkName = trim($checkName);

    if (exists($mailUIDHash{$checkUID}))
    {
        printLOG("User exists with email: $mailUIDHash{$checkUID} and name: $checkName");
        return $mailUIDHash{$checkUID};
    }
    else
    {
        printLOG("Cant find $checkUID, $checkName user in mailUIDHash");
        return;
    }
}

sub updateZimbraInfo
{
    my $email = shift;
    my $pass = shift;
    my $name = shift;
    my $group = shift;
    my $department = shift;

    my ($first, $last, $middle) = split(/ /, trim($name));
    printLOG("Updating $email, setting name: $name and group: $group");

    open(my $tmp, ">/tmp/tmpUpdateZimbra") or die "Cant open file /tmp/tmpUpdateZimbra, $!\n";

        print $tmp "sp $email \"$pass\"\n";

    if ($last)
    {
        print $tmp "ma $email givenName \"$last\"\n";
    }

    if ($first)
    {
        print $tmp "ma $email sn \"$first\"\n";
    }

    if ($middle)
    {
        print $tmp "ma $email initials \"$middle\"\n";
    }

    if ($first && $last)
    {
        print $tmp "ma $email displayName \"$first $last\"\n";
    }

    if ($university)
    {
        print $tmp "ma $email company \"$university\"\n";
    }

    if ($city)
    {
        print $tmp "ma $email l \"$city\"\n";
    }

    if ($country)
    {
        print $tmp "ma $email co \"$country\"\n";
    }

    if ($title)
    {
        print $tmp "ma $email title \"$title\"\n";
    }

    if ($department)
    {
        print $tmp "ma $email description \"$department\"\n";
    }
        # deleted because we should know user password
        #print $tmp "ma $email zimbraPasswordMustChange TRUE";

        my $exec = `su - zimbra -c 'zmprov -f /tmp/tmpUpdateZimbra'`;
}

sub addUserToGroup
{
    my $email = shift;
    my $name = shift;
    my $pass = shift;
    my $group = shift;
    my $kafedra = shift;

    my ($first, $last, $middle) = split(/ /, trim($name));
    my ($username, $dom) = split(/\@/, trim($email));

    if (!$first)
    {
        $first = "NULL";
    }

    if (!$last)
    {
        $last = "NULL";
    }

    if (!$middle)
    {
        $middle = "NULL";
    }

    if ($group)
    {
        if ($kafedra)
        {
            $group = trim($group);
            $kafedra = trim($kafedra);

            unless (-e $kafedra or mkdir $kafedra)
            {
                die "Cant craete folder $kafedra\n";
            }

            open(my $tmp, ">>$kafedra/$group") or die "Cant open file $kafedra/$group, $!\n";
                print $tmp "$username,$pass,$first,$last,$middle,$groupPrefix$group\_$groupSuffix\n";
            printLOG("User: $email, was added to $kafedra/$group");
        }
        else
        {
            $group = trim($group);

            open(my $tmp, ">>$group") or die "Cant open file $group, $!\n";
                print $tmp "$username,$pass,$first,$last,$middle,$groupPrefix$group\_$groupSuffix\n";
            printLOG("User: $email, was added to $group");
        }

        open(my $cohort, ">>$cohortsFile") or die "Cant open file $cohortsFile, $!\n";
            print $cohort "$username,$pass,$first,$last,$middle,$groupPrefix$group\_$groupSuffix,$country,$city,$university\n";
    }
    else
    {
        open(my $tmp, ">>no-group") or die "Cant open file no-group, $!\n";
            print $tmp "$username,$pass,$first,$last,$middle,$groupPrefix"."no-group_$groupSuffix,$country,$city,$university\n";
    }
}

sub addGroup
{
    my $firstUid = shift;
    my $group = shift;
    my $description = shift;

    if (!$group)
    {
        $group = "no_group_".$groupSuffix;
    }
    else
    {
        $group = $groupPrefix.$group."_".$groupSuffix;
    }

    if(exists($groups{$group}))
    {
        printLOG("Such group: $group already exists, with first uid: $groups{$group}");
    }
    else
    {
        open(my $tmp, ">>$groupsFile") or die "Cant open file $groupsFile, $1\n";
            print $tmp "$group,$group,$description\n";

        printLOG("Group: $group was added to $groupsFile, and first user is $firstUid");

        $groups{$group} = $group;
    }
}
