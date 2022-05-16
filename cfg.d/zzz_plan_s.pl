$c->{plan_s_set_document_defaults} = $c->{set_document_defaults};
$c->{set_document_defaults} = sub
{
    my( $data, $repository, $eprint ) = @_;

    $repository->call( "plan_s_set_document_defaults", $data, $repository, $eprint );
    
    $data->{license} = "cc_by_4" if !defined $data->{license};
};
