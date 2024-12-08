#!/usr/bin/perl

use strict;
use warnings;
use IO::Socket::INET;
use FindBin;  # Module to find script directory
use File::Spec;  # Module to handle paths
use Crypt::CBC;
# use Crypt::Random;

# Configuration
my $script_dir = $FindBin::Bin;  # Get the directory of the current script
my $uploads_dir = File::Spec->catdir($script_dir, "uploads");  # Construct the path to the uploads folder
my $encryption_key = 'sharedsecretkey';

# Check for valid arguments
my ($host, $username, $password, $command) = @ARGV;
if (!$host || !$username || !$password || !$command) {
    die "Usage: perl client.pl <host> <username> <password> <command> [<file_path>]\n";
}

# Connect to the server
my $socket = IO::Socket::INET->new(
    PeerAddr => $host,
    PeerPort => 5000,
    Proto    => 'tcp'
) or die "Could not connect to server: $!";

$| = 1; # Enable autoflush

# Handle the command
if ($command eq 'CREATEUSER') {
    print $socket "CREATE_USER $username $password\n";
    my $response = <$socket>;
    print $response;
    close $socket;
    exit;
}
elsif ($command eq 'LOGIN') {
    print $socket "LOGIN $username $password\n";
    my $response = <$socket>;
    if ($response =~ /LOGIN SUCCESS/) {
        print "Login successful. You can now enter commands.\n";
        while (1) {
            print "Enter command: ";
            my $user_command = <STDIN>;
            chomp $user_command;

            if (uc($user_command) eq 'EXIT') {
                print $socket "EXIT\n";
                print "Exiting the client. Goodbye!\n";
                close $socket;
                last;
            }

            # Handle file upload command separately
            if ($user_command =~ /^UPLOAD\s+(.+)/i) {
                my $file_path = $1;
                upload_file($socket, $file_path);
                next;
            }

            # Handle file download command seperately
            if ($user_command =~ /^DOWNLOAD\s+(.+)/i) {
                my $filename = $1;
                download_file($socket, $filename);
                next;
            }

            # Handle the DELETE command
            elsif ($user_command =~ /^DELETE\s+(.+)/i) {
                my $filename = $1;
                delete_file($socket, $filename);
                next;
            }

            # Handle the SHARE command
            elsif ($user_command =~ /^SHARE\s+(\S+)\s+(\S+)\s+(.+)/i) {
                my ($command, $owner, $recipient, $filename) = split(' ', $user_command, 4);
                share_file($socket, $owner, $recipient, $filename);
                next;
            }

            # Send other commands to the server
            print $socket "$user_command\n";

            # Read and print response from server
            my $server_response = <$socket>;
            print $server_response;
        }
    } else {
        die "Login failed: $response\n";
    }
} 

else {
    die "Invalid command. Supported commands: CREATEUSER, LOGIN, UPLOAD.\n";
}

close ($socket);

# Subroutine to handle file uploads
sub upload_file {
    my ($socket, $filename) = @_;

    print $socket "UPLOAD $filename\n";  # Send the relative filename to the server
    my $response = <$socket>;
    if ($response =~ /READY_TO_RECEIVE/) {
        open my $file, '<:raw', $filename or die "Cannot open file: $!\n";
        while (my $buffer = <$file>) {
            print $socket $buffer;
        }
        close $file;
        print $socket "EOF\n";
        my $upload_response = <$socket>;
        print $upload_response;
    } else {
        print "Server error: $response\n";
    }

}

# Subroutine for downloading a file
sub download_file {
    my ($socket, $filename) = @_;

    print $socket "DOWNLOAD $filename\n";
    my $response = <$socket>;

    if ($response =~ /DOWNLOAD SUCCESS/) {
        my $local_file = File::Spec->catfile($uploads_dir, $filename);
        open my $file, '>:raw', $local_file or die "Cannot create file: $!\n";

        while (my $buffer = <$socket>) {
            last if $buffer =~ /EOF/;
            print $file $buffer;
        }
        close $file;

    } else {
        print "Server error: $response\n";
    }
}

# Subroutine for deleting a file
sub delete_file {
    my ($socket, $filename) = @_;
    print $socket "DELETE $filename\n";
    my $response = <$socket>;
    print "Server response: $response";
}

# Share file command
sub share_file {
    my ($socket, $owner, $recipient, $filename) = @_;
    
    # Send the SHARE command to the server
    print $socket "SHARE $owner $recipient $filename\n";
    
    # Read and print the server's response
    my $response = <$socket>;
    print "Server Response: $response\n";
}

