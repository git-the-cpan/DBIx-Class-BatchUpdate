package DBIx::Class::BatchUpdate::Update;
$DBIx::Class::BatchUpdate::Update::VERSION = '1.003';
use Moo;
use autobox::Core;
use true;

use Storable qw/ nfreeze /;

use DBIx::Class::BatchUpdate::Batch;



has rows => ( is => "ro", required => 1 );

has resultset => (is => "lazy");
sub _build_resultset {
    my $self = shift;
    my $row = $self->rows->[0] or return undef;
    return $row->result_source->resultset();
}

has batches => ( is => "lazy");
sub _build_batches {
    my $self = shift;
    $self->resultset or return [];

    my $key_batch = {};
    for my $row ($self->rows->elements) {
        my $key_value = { $row->get_dirty_columns };
        my $batch_key = $self->batch_key($key_value) or next;
        my $batch = $key_batch->{ $batch_key } //= DBIx::Class::BatchUpdate::Batch->new({
            key_value => $key_value,
            resultset => $self->resultset,
            key       => $batch_key,
        });
        $batch->ids->push( $row->id );
    };

    # Sort to get some semblance of determinism wrt insert ordering
    return [ sort { $a->key cmp $b->key } $key_batch->values ];
}

sub batch_key {
    my $self = shift;
    my ($key_value) = @_;
    keys %$key_value or return undef;

    # sort hash keys for a stable representation
    local $Storable::canonical = 1;
    return nfreeze(
        {
            # Assume the pk isn't dirty
            map {
                my $value = $key_value->{$_};
                $_ => defined($value) ? "$value" : undef;
            }
            keys %$key_value,
        },
    );
}

sub update {
    my $self = shift;
    for my $batch ( $self->batches->elements ) {
        $batch->update();
    }
}
