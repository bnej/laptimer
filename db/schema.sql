create table club (
    club_id varchar(10) not null,
    club_name varchar(60) not null,
    primary key (club_id)
);

create table club_user (
    club_id varchar(10) not null references club(club_id) on delete cascade,
    username varchar(20) not null,
    password varchar(64) not null,
    primary key (username)
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

create table result_place (
    event_id integer references event (event_id) on delete cascade,
    place integer not null,
    athlete_id integer references athlete (athlete_id) on delete cascade,
    best_lap integer not null,
    total_time integer not null,
    event_laps integer not null,
    primary key (event_id, place)
);

create index result_place_athlete_idx on result_place (athlete_id);

create table result_lap (
    event_id integer references event (event_id) on delete cascade,
    athlete_id integer references athlete (athlete_id) on delete cascade,
    lap integer not null,
    lap_time integer not null,
    primary key (athlete_id, lap)
);

create index result_lap_event_idx on result_lap (event_id);
