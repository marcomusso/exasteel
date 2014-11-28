package Exasteel::Controller::Pages;

use Mojo::Base 'Mojolicious::Controller';
#use Switch;
use DateTime;
use Data::Dumper;
use Mojo::Log;
use Mojo::Headers;

# Customize log file location and minimum log level
my $log = Mojo::Log->new(path => 'log/exasteel.log', level => 'debug');
my $debug=2;

# landing page
sub home {
  my $self = shift;
  if (defined $self->session->{username} and $self->session->{username} ne '') {
    $self->render('home');
  } else {
    $self->redirect_to('/login');
  }
}

# landing page
sub settings {
  my $self = shift;
  $self->render('pages/settings');
}
