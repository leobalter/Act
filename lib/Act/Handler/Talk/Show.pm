package Act::Handler::Talk::Show;
use strict;
use parent 'Act::Handler';
use Act::Config;
use Act::Template::HTML;
use Act::Tag;
use Act::Talk;
use Act::Abstract;

sub handler
{
    # retrieve talk_id
    my $talk_id = $Request{path_info};
    unless ($talk_id =~ /^\d+$/) {
        $Request{status} = 404;
        return;
    }
    # retrieve talk
    my $talk = Act::Talk->new(
        talk_id => $talk_id,
        $Request{conference} ? ( conf_id => $Request{conference} ) : ()
    );

    # available only if submissions open or organizer
    unless ($talk
            && ( $Config->talks_show_all
                 || $talk->accepted
                 || ($Request{user} && $Request{user}->is_talks_admin)
                 || ($Request{user} && $Request{user}->user_id == $talk->user_id) ) )
    {
        $Request{status} = 404;
        return;
    }

    # only organizer or submitter may see non accepted talk
    # except when the config says show_all !
    undef $talk
        if !$Config->talks_show_all
        && $talk
        && !$talk->{accepted}
        && !($Request{user}
             && ($Request{user}->user_id == $talk->user_id
                 || $Request{user}->is_talks_admin));

    # retrieve talk's speaker info
    my $user;
    $user = Act::User->new(user_id => $talk->user_id)
        if $talk;

    unless ($talk && $user) {
        $Request{status} = 404;
        return;
    };

    # retrieve tags
    my @tags = Act::Tag->fetch_tags(
                    conf_id     => $Request{conference},
                    type        => 'talk',
                    tagged_id   => $talk_id,
               );

    # add tags
    if ($Request{user} && $Request{args}{ok}) {
        my %oldtags = map { $_ => 1 } @tags;
        my @newtags = grep !$oldtags{$_}, Act::Tag->split_tags($Request{args}{newtags});
        if (@newtags) {
            Act::Tag->update_tags(
                conf_id     => $Request{conference},
                type        => 'talk',
                tagged_id   => $talk_id,
                oldtags     => \@tags,
                newtags     => [  @tags, @newtags ],
            );
        }
        Act::Util::redirect( $Request{r}->uri );
    }

    # process the template
    my $template = Act::Template::HTML->new();

    $template->variables(
        %$talk,
        chunked_abstract => Act::Abstract::chunked( $talk->abstract ),
        user => $user,
        tags => \@tags,
        attendees => Act::User->attendees($talk_id),
    );

    $template->variables(
        level => $Config->talks_levels_names->[ $talk->level - 1 ],
    ) if $Config->talks_levels;

    $template->process('talk/show');
    return;
}

1;
__END__

=head1 NAME

Act::Handler::User::Show - show userinfo

=head1 DESCRIPTION

See F<DEVDOC> for a complete discussion on handlers.

=cut
