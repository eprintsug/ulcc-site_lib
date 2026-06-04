package EPrints::Plugin::Screen::Report::Request;

use EPrints::Plugin::Screen::Report;
our @ISA = ( 'EPrints::Plugin::Screen::Report' );

use strict;

sub new
{
    my( $class, %params ) = @_;

    my $self = $class->SUPER::new( %params );

    $self->{datasetid} = 'request';
    $self->{searchdatasetid} = 'request';
    $self->{custom_order} = '-datestamp/';
    $self->{appears} = [];
    $self->{report} = 'request_report';
    $self->{sconf} = 'request_report';
    $self->{export_conf} = 'request_report';
    $self->{sort_conf} = 'request_report';
    $self->{group_conf} = 'request_report';

    $self->{disable} = 0;

    $self->{labels} = {
        outputs => "Requests"
    };

    $self->{show_compliance} = 0;

    return $self;
}

sub can_be_viewed
{
    my( $self ) = @_;

    return 0 if( !$self->SUPER::can_be_viewed );
    
    return $self->allow( 'report/request' );
}

sub ajax_request
{
    my( $self ) = @_;

    my $repo = $self->repository;

    my $json = { data => [] };

    $repo->dataset( "request" )
        ->list( [$repo->param( "request" )] )
        ->map(sub {
            (undef, undef, my $request) = @_;

            return if !defined $request; # odd

            my $frag = $request->render_citation_link;
            push @{$json->{data}}, {
                datasetid => $request->dataset->base_id,
                dataobjid => $request->id,
                summary => EPrints::XML::to_string( $frag ),
#               grouping => sprintf( "%s", $user->value( SOME_FIELD ) ),
                problems => [ $self->validate_dataobj( $request ) ],
                bullets => [ $self->bullet_points( $request ) ],
           };
        });
    print $self->to_json( $json );
}
                       
sub validate_dataobj
{
    my( $self, $request ) = @_;

    my $repo = $self->{repository};

    my @problems;

    return @problems;
}

sub bullet_points
{
    my( $self, $request ) = @_;

    my $repo = $self->{repository};

    my @bullets;

    return @bullets;
}

1;
