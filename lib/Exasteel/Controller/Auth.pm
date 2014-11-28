package Exasteel::Controller::Auth;

use base 'Mojolicious::Controller';
use strict;
use warnings;
use Data::Dumper;
use Mojo::Log;

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/auth.log', level => 'debug');
my $debug=1;

sub create {
  my $self     = shift;
  my $username = $self->param('username');
  my $password = $self->param('password');

  if ($debug>0) { $log->debug("Exasteel::Controller::Auth::create"); }

  if ($username eq "admin" && $password eq "admin") {
    $self->session(
      username => $username,
      email    => ''
      )->redirect_to('/');
  } else {
    if ($debug>0) { $log->debug("Exasteel::Controller::Auth::create login failed for $username"); }
    $self->flash( error => 'Unknown username or wrong password' )->redirect_to('auth_login');
  }
}

sub delete {
  my $self = shift;

  if ($debug>0) { $log->debug("Exasteel::Controller::Auth::delete logout for ".$self->session('username')); }
  $self->session( username => '' )->redirect_to('auth_login');
}

sub check {
  my $self = shift;

  if ($self->session('username')) {
    return 1;
  } else {
    $self->render(template => 'auth/denied');
    return 0;
  }
}

"The gate will open if...";
