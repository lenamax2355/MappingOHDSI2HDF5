--Inorder to map the tables to JSON and then to HDF5 flatten the table

--create a denormalized tables for the main OHDSI table
--convert date and time separately to date / time

--TODO:


-- Check Start
-- select count(*) from person;
-- 17950
-- Check End

drop table if exists map2_person;
create table map2_person as 
select t.*, cast(to_char(cast(birth_date as date), 'J') as int) as birth_julian_day from (
  select p.*,
    cast(
      cast(p.year_of_birth as varchar(4)) || '-' || 
        right('0' || cast(p.month_of_birth as varchar(2)), 2) || '-' || 
        right('0' || cast(p.day_of_birth as varchar(2)), 2)
      as date) as birth_date,
    c1.concept_name as gender_concept_name,
    c1.concept_code as gender_concept_code,
    c2.concept_name as ethnicity_concept_name,
    c3.concept_name as race_concept_name
    from person p 
    join concept c1 on c1.concept_id = p.gender_concept_id
    left outer join concept c2 on c2.concept_id = p.race_concept_id
    left outer join concept c3 on c3.concept_id = p.ethnicity_concept_id) t
;

select * from map2_person limit 100;

create unique index idx_map2_person_p_id on map2_person(person_id);

select count(*) from map2_person;
--17950

--TODO: left outer join provider
--TODO: left outer join location

select count(*) from visit_occurrence;
--344354

drop table if exists map2_visit_occurrence;
create table map2_visit_occurrence as
select *, cast(floor(age_at_visit_start_in_years_fraction) as int) as age_at_visit_start_in_years_int from (
  select tt.*, 
    (visit_start_julian_day - birth_julian_day) / 365.25 as age_at_visit_start_in_years_fraction ,
    visit_start_julian_day - birth_julian_day as age_at_visit_start_in_days
  from (
    select t.*, 
      cast(to_char(cast("visit_start_date" as date), 'J') as int) as visit_start_julian_day,
      cast(to_char(cast("visit_end_date" as date), 'J') as int) as visit_end_julian_day from (
      select vo.*, c1.concept_name as visit_concept_name, c2.concept_name as visit_type_concept_name,
        cast( --create a timestamp
            cast(vo.visit_start_date as varchar(10)) || ' ' || 
                case when vo.visit_start_time is null then '' else vo.visit_start_time end as
            timestamp) as visit_start_datetime, --e5.1 version
        cast(
            cast(vo.visit_end_date as varchar(10)) || ' ' || 
              case when vo.visit_end_time is null then '' else vo.visit_end_time end 
             as timestamp) as visit_end_datetime
        from visit_occurrence vo 
          join concept c1 on vo.visit_concept_id = c1.concept_id
          join concept c2 on vo.visit_type_concept_id = c2.concept_id) t) tt
        join map2_person mp on mp.person_id = tt.person_id) ttt
        ;
--344354 rows affected      

create unique index idx_map2_visit_occur_id on map2_visit_occurrence(visit_occurrence_id);      

create table map2_person_visit_occurrence as 
  select vo.visit_occurrence_id, p.* from visit_occurrence vo
    join map2_person p on vo.person_id = p.person_id
;

--TODO: Add caresite
--TODO: Person Age 
            
select count(*) from condition_occurrence;            
--715755

            
drop table if exists map2_condition_occurrence;
create table map2_condition_occurrence as
select *, cast(floor(tt.condition_start_age_in_years_fraction) as int) as condition_start_age_in_years_int from (
  select t.*,  (condition_start_julian_day - p.birth_julian_day) / 365.25 as condition_start_age_in_years_fraction,
    (condition_start_julian_day - p.birth_julian_day) as condition_start_age_in_days
  from (
    select co.*,
      cast(to_char(cast(co.condition_start_date as date), 'J') as int) as condition_start_julian_day,
      c1.concept_name as source_condition_concept_name, c1.concept_code as source_condition_concept_code,
        c1.vocabulary_id as source_condition_vocabulary_id,
      c2.concept_name as condition_concept_name, c2.concept_code as condition_concept_code,
        c2.vocabulary_id as condition_vocabulary_id,
      c3.concept_name as condition_type_name
    from condition_occurrence co 
      join concept c1 on c1.concept_id = co.condition_source_concept_id
      join concept c2 on c2.concept_id = co.condition_concept_id
      join concept c3 on c3.concept_id = co.condition_type_concept_id) t
      join map2_person p on p.person_id = t.person_id) tt
    ;
--715755 rows affected
create unique index idx_map2_visit_occur_id on map2_visit_occurrence(visit_occurrence_id);

select * from map2_condition_occurrence limit 100;
  
  
 select count(*) from procedure_occurrence;
 --638557
  
drop table if exists map2_procedure_occurrence;
create table map2_procedure_occurrence as 
  select tt.*, floor(tt.procedure_age_in_years_fraction) as procedure_age_in_years_int from (
    select t.*, (procedure_julian_day - p.birth_julian_day) / 365.25 as procedure_age_in_years_fraction,
    (procedure_julian_day - p.birth_julian_day) as procedure_age_in_days
    from (
      select po.*, 
        cast(to_char(cast(po.procedure_date as date), 'J') as int) as procedure_julian_day,
        c1.concept_name as procedure_source_concept_name, 
        c1.concept_code as procedure_source_concept_code,
        c1.vocabulary_id as procedure_source_vocabulary_id,
        c2.concept_name as procedure_concept_name, 
        c2.concept_code as procedure_concept_code,
        c2.vocabulary_id as procedure_vocabulary_id,
        c3.concept_name as procedure_type_name,
        c3.concept_code as procedure_type_code,
        c4.concept_name as modifier_concept_name,
        c4.concept_code as modifier_concept_code,
        c4.vocabulary_id as modifier_concept_vocabulary_id
        from procedure_occurrence po 
        join concept c1 on c1.concept_id = po.procedure_source_concept_id
        join concept c2 on c2.concept_id = po.procedure_concept_id
        join concept c3 on c3.concept_id = po.procedure_type_concept_id
        left outer join concept c4 on c4.concept_id = po.modifier_concept_id) t
        join map2_person p on t.person_id = p.person_id) tt;
--638557 rows affected  

select * from map2_procedure_occurrence limit 100;

select count(*) from observation;
--2,388,529

drop table if exists map2_observation;
create table map2_observation as
select tt.*,
  floor(tt.observation_age_in_years_fraction) as observation_age_in_years_int
from (
  select t.*, 
    (t.observation_julian_day - p.birth_julian_day) / 365.25 as observation_age_in_years_fraction, 
    (t.observation_julian_day - p.birth_julian_day) as observation_age_in_days from (
    select o.*,
          cast(to_char(cast(o.observation_date as date), 'J') as int) as observation_julian_day,
          cast(cast(o.observation_date as varchar(10)) || ' ' || o.observation_time as timestamp) as observation_datetime,
          c1.concept_name as observation_source_concept_name, 
          c1.concept_code as observation_source_concept_code,
          c1.vocabulary_id as source_vocabulary_id,
          c2.concept_name as observation_concept_name, 
          c2.concept_code as observation_concept_code,
          c2.vocabulary_id as concept_vocabulary_id,
          c3.concept_name as value_as_concept_name,
          c3.concept_code as value_as_concept_code,
          c3.vocabulary_id as value_as_concept_vocabulary_id,
          c4.concept_name as unit_concept_name,
          c4.concept_code as unit_concept_code,
          c4.vocabulary_id as unit_concept_vocabulary_id,
          c5.concept_name as qualifier_concept_name
    from observation o
    join concept c1 on o.observation_source_concept_id = c1.concept_id
    join concept c2 on o.observation_concept_id = c2.concept_id
    left outer join concept c3 on o.value_as_concept_id = c3.concept_id
    left outer join concept c4 on o.unit_concept_id = c4.concept_id 
    left outer join concept c5 on o.qualifier_concept_id = c5.concept_id) t
   join map2_person p on t.person_id = p.person_id) tt
;

select count(*) from map2_observation;
--2,388,529

select * from map2_observation limit 100;

select count(*) from measurement;
--9438251

drop table if exists map2_measurement;
create table map2_measurement as 
select tt.*,
  floor(tt.measurement_age_in_years_fraction) as measurement_age_in_years_int
from (
  select t.*, 
    (t.measurement_julian_day - p.birth_julian_day) / 365.25 as measurement_age_in_years_fraction, 
    (t.measurement_julian_day - p.birth_julian_day) as measurement_age_in_days
  from (
  select m.*,
        cast(to_char(cast(m.measurement_date as date), 'J') as int) as measurement_julian_day,
        cast(cast(m.measurement_date as varchar(10)) || ' ' || m.measurement_time as timestamp) as measurement_datetime,
        c1.concept_name as measurement_source_concept_name, 
        c1.concept_code as measurement_source_concept_code,
        c1.vocabulary_id as source_vocabulary_id,
        c2.concept_name as measurement_concept_name, 
        c2.concept_code as measurement_concept_code,
        c2.vocabulary_id as concept_vocabulary_id,
        c3.concept_name as value_as_concept_name,
        c3.concept_code as value_as_concept_code,
        c3.vocabulary_id as value_as_concept_vocabulary_id,
        c4.concept_name as unit_concept_name,
        c4.concept_code as unit_concept_code,
        c4.vocabulary_id as unit_concept_vocabulary_id,
        c5.concept_name as operator_concept_name
  from measurement m
  join concept c1 on m.measurement_source_concept_id = c1.concept_id
  join concept c2 on m.measurement_concept_id = c2.concept_id
  left outer join concept c3 on m.value_as_concept_id = c3.concept_id
  left outer join concept c4 on m.unit_concept_id = c4.concept_id 
  left outer join concept c5 on m.operator_concept_id = c5.concept_id) t
  join map2_person p on p.person_id = t.person_id) tt
  ;

select count(*) from map2_measurement;
--9438251

select * from map2_measurement limit 100;

select count(*) from drug_exposure;
--970755
 
drop table if exists map2_drug_exposure;
create table map2_drug_exposure as 
  select tt.*, floor(drug_exposure_start_age_in_years_fraction) as drug_exposure_start_age_in_years_int from (
    select t.*,
        (t.drug_exposure_start_julian_day - p.birth_julian_day) / 365.25 as drug_exposure_start_age_in_years_fraction, 
        (t.drug_exposure_start_julian_day - p.birth_julian_day) as drug_exposure_start_age_in_days
    from (
      select de.*,
        cast(to_char(cast(de.drug_exposure_start_date as date), 'J') as int) as drug_exposure_start_julian_day,
        cast(to_char(cast(de.drug_exposure_end_date as date), 'J') as int) as drug_exposure_end_julian_day,
        c1.concept_name as drug_concept_source_name,
        c1.concept_code as drug_concept_source_code,
        c1.vocabulary_id as drug_concept_source_vocabulary_id,
        c2.concept_name as drug_concept_name,
        c2.concept_code as drug_concept_code,
        c2.vocabulary_id as drug_concept_vocabulary_id,
        c3.concept_name as drug_type_concept_name,
        c3.concept_code as drug_type_concept_code,
        c3.vocabulary_id as drug_type_concept_vocabulary_id,
        c4.concept_name as route_concept_name,
        c4.concept_code as route_concept_code,
        c4.vocabulary_id as route_concept_vocabulary_id,
        c5.concept_name as unit_concept_name,
        c5.concept_code as unit_concept_code,
        c5.vocabulary_id as unit_concept_vocabulary_id
      from drug_exposure de
        join concept c1 on c1.concept_id = de.drug_source_concept_id
        join concept c2 on c2.concept_id = de.drug_concept_id
        left outer join concept c3 on c3.concept_id = de.drug_type_concept_id
        left outer join concept c4 on c4.concept_id = de.route_concept_id
        left outer join concept c5 on c5.concept_id = de.dose_unit_concept_id
    ) t join map2_person p on t.person_id = p.person_id) tt 
    ;
    
select count(*) from map2_drug_exposure;  
--970755