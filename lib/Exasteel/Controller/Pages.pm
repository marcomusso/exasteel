package Exasteel::Controller::Pages;

use Mojo::Base 'Mojolicious::Controller';
use DateTime;
use Data::Dumper;

# landing page
sub home {
  my $self = shift;
  $self->render('home')
}

# landing page
sub settings {
  my $self = shift;
  $self->render('pages/settings');
}

# vDC details
sub vdcdetails {
  my $self = shift;
  $self->render('pages/vdcdetails');
}

"You know, it occurs to me that the best way you hurt rich people is by turning them into poor people. (Trading places, 1983)";
