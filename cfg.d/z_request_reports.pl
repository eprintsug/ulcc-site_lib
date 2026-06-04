$c->{plugins}{"Screen::Report::Request"}{params}{disable} = 0;
$c->{plugins}{"Screen::Report::Request"}{params}{custom} = 1;

$c->{reports}->{csv_utf8_bom} = 1;

#set config for default user report
$c->{datasets}->{request}->{search}->{request_report} = 
{
    search_fields => [
        { meta_fields => [ "eprintid", ] },
        { meta_fields => [ "datestamp", ] },
        { meta_fields => [ "email", ] },
        { meta_fields => [ "requester_email", ] },
    ],
    citation => "result",
    page_size => 20,
    show_zero_results => 1,
};


#export field options
$c->{request_report}->{exportfields} = {
    request_report_core => [ qw(
    	requestid
        eprintid
        docid
        datestamp
        userid
        email
        requester_email
        reason
        expiry_date
    )],
};

#set order of export plugins
$c->{request_report}->{export_plugins} = [ qw( Export::Report::CSV )];

push @{$c->{user_roles}->{admin}}, qw{
    +report/request
};
