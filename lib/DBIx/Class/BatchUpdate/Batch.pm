package DBIx::Class::BatchUpdate::Batch;
$DBIx::Class::BatchUpdate::Batch::VERSION = '1.000';
use Moo;
use true;

has key_value => ( is => "ro", required => 1 );
has resultset => ( is => "ro", required => 1 );
has key       => ( is => "ro", required => 1 );

has ids => ( is => "lazy" );
sub _build_ids { [] }

sub update {
    my $self = shift;
    $self->resultset
        ->search({ id => { -in => $self->ids } })
        ->update( $self->key_value );
}
