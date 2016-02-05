package DBIx::Class::BatchUpdate::Update;
$DBIx::Class::BatchUpdate::Update::VERSION = '1.002';
use Moo;
use autobox::Core;
use true;

use Digest::MD5 "md5";

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

    # Assume the pk isn't dirty
    return join(
        ", ",
        map { $self->safe_key_value($_, $key_value->{ $_ }) }
        sort keys %$key_value,
    );
}

sub safe_key_value {
    my $self = shift;
    my ($key, $value) = @_;
    my $safe_value = defined $value
        ? md5("$value")
        : "undef";

    return "$_: $safe_value";
}

sub update {
    my $self = shift;
    for my $batch ( $self->batches->elements ) {
        $batch->update();
    }
}
