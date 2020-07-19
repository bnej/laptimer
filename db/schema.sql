create table club (
    club_id varchar(10) not null,
    club_name varchar(60) not null,
    primary key (club_id)
);

create table event (
    club_id      varchar(10) references club(club_id) on delete cascade,
    event_id     serial not null,
    event_name   varchar(60) not null,
    event_text   text,
    start_lap    integer,
    total_laps   integer,
    event_active boolean default true,
    primary key (event_id)
);

create table athlete (
    club_id varchar(10) references club(club_id) on delete cascade,
    athlete_id serial not null,
    athlete_name text,
    athlete_alias text,
    primary key (athlete_id)
);

create table time_mark (
    event_id     integer references event (event_id) on delete cascade,
    timing_number integer not null,
    timing_mark   integer not null,
    primary key ( event_id, timing_number )
);

create table place_mark (
    event_id integer references event (event_id) on delete cascade,
    timing_number integer not null,
    athlete_id integer references athlete (athlete_id) on delete cascade,
    primary key ( event_id, timing_number )
);
