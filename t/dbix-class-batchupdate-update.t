use strict;
use warnings;
use Test::More;
use Test::Differences;
use Test::MockObject;

use DBIx::Class::BatchUpdate::Update;



my $empty_batch = DBIx::Class::BatchUpdate::Update->new({ rows => [] });



# batch_key
is(
    $empty_batch->batch_key({ id => 3, price => 42, author_id => undef }),
    "(((author_id: \t\t\t<undef>\t\t\t)))\tD::C::R::U\t(((id: 3)))\tD::C::R::U\t(((price: 42)))",
    "Correct batch_key",
);



### Empty rows
is_deeply(
    $empty_batch->batches,
    [],
    "Empty rows, no batches",
);



### Rows with different values

## Setup

my $update_call_count = 0;
my $search_args = [];
my $resultset = Test::MockObject->new
    ->mock(
        search => sub {
            my $self = shift;
            my ($args) = @_;
            push(@$search_args, $args);
            Test::MockObject->new
                ->mock(update => sub { $update_call_count++ }),
            },
    );

sub get_row {
    my ($row_id, $key_value) = @_;
    return Test::MockObject->new
        ->set_always(id => $row_id)
        ->mock(get_dirty_columns => sub { return %$key_value })
        ->mock(
            result_source => sub {
                Test::MockObject->new->set_always(resultset => $resultset)
            },
        )
        ;
}

my $rows = [
    get_row(1, { is_out_of_print => 1 }),
    get_row(2, { is_out_of_print => 1 }),
    get_row(3, { is_out_of_print => 1, price => 42 }),
];

my $batch = DBIx::Class::BatchUpdate::Update->new({ rows => $rows });

## Run
$batch->update();


## Test
is($update_call_count, 2, "update was called once for each combo");
eq_or_diff(
    $search_args,
    [
        { id => { -in => [ 1, 2 ] } }, # is_out_of_print
        { id => { -in => [ 3 ] } },    # is_out_of_print, price
    ],
);



done_testing;
