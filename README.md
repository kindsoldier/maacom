# Maacom - Web mail account manager

I wrote this application for using into small-middle corporation. I wanted to write a simple classic object-oriented web application, that can be used as a training application.

The application wrote with

  - Perl Mojolicious as MVC framework and
  - Zurb Foundation as CSS

Work example of configuration Exim and Dovecot attached below the page http://wiki.unix7.org/perl/maacom

You can

  -    Easy add, delete, rename and edit domain, user and alias records. You can rename entire domain with safe all your accounts!
  -    Set personal and domain mail quotas (still in progress but already calculates size of mail dirs in background)
  -    Edit/use additional list of forwarded domain, lists of unwanted and trusted hosts
  -    Live view tail of mail log from operation system for debugging purpose.
  -    Configure mail relay and then send a love letter to a loved one =)

Password file in the same Apache htpasswd format.

The application is ready to use, the installation procedure takes 10-15 minutes.
The procedure is described on the project page http://wiki.unix7.org/perl/maacom

![](http://wiki.unix7.org/_media/perl/screenshot-2017-12-11-21-39-52.png?w=420)

