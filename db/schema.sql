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

create table event_type (
    event_type_id varchar(10) not null,
    event_type_name varchar not null,
    start_lap integer,
    total_laps integer,
    lap_length float,
    repeat boolean default false,
    primary key (event_type_id)
);
insert into event_type values ('4kp_t','4km Individual Pursuit Tempe',1,12,333.3,false);
insert into event_type values ('f200_t','Flying 200 Tempe',1,1,200,true);
insert into event_type values ('kilo_t','Kilo Tempe',1,3,333.3,true);

alter table event add event_type_id varchar(10) references event_type;

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
    effort integer not null,
    best_lap integer not null,
    total_time integer not null,
    event_laps integer not null,
    primary key (event_id, place, effort)
);

create index result_place_athlete_idx on result_place (athlete_id);

create table result_lap (
    event_id integer references event (event_id) on delete cascade,
    athlete_id integer references athlete (athlete_id) on delete cascade,
    effort integer not null,
    lap integer not null,
    lap_time integer not null,
    primary key (event_id, athlete_id, effort, lap)
);

create index result_lap_event_idx on result_lap (event_id);

alter table time_mark add time_ms bigint;

alter table place_mark add place_ms bigint;
