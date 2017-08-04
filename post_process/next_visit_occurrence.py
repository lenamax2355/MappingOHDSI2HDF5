
"""

Visits:
/ohdsi/visit_occurrence

Person:

/ohdsi/identifiers
person_id

/computed/next/has/visit_occurrence/core_array
/computed/next/has/visit_occurrence/column_annotations

# Number of days to next visit

/computed/next/days/visit_occurrence/core_array
/computed/next/days/visit_occurrence/column_annotations

# Position in matrix of next visit
/computed/next/position/visit_occurrence/core_array
/computed/next/position/visit_occurrence/column_annotations

visit_concept_name	Inpatient Visit
visit_concept_name	No matching concept
visit_concept_name	Outpatient Visit

"""

import numpy as np
import h5py
import argparse
import shutil


def index_annotations(column_annotations, field_name):

    column_list = column_annotations[0,:].tolist()

    if field_name in column_list:
        start_position = column_list.index(field_name)
        reverse_column_list = list(column_list)
        reverse_column_list.reverse()
        end_position = len(column_list) - reverse_column_list.index(field_name)

        return (start_position, end_position)
    else:
        return None


def main(hdf5_file_name, make_backup=False):

    # Get positions to slice

    if make_backup:
        print("Making backup copy of file")
        shutil.copy(hdf5_file_name, hdf5_file_name + ".bak")

    f5 = h5py.File(hdf5_file_name, "r+")
    path_to_visit = "/ohdsi/visit_occurrence/"

    visit_concept_name = "visit_concept_name"

    visit_annotations_path = path_to_visit + "column_annotations"

    visit_annotations = f5[visit_annotations_path][...]

    slice_visit_concept_name = index_annotations(visit_annotations, visit_concept_name)

    visit_start = "visit_start_julian_day"
    visit_end = "visit_end_julian_day"

    slice_visit_start = index_annotations(visit_annotations, visit_start)
    slice_visit_end = index_annotations(visit_annotations, visit_end)

    path_to_identifiers = "/ohdsi/identifiers/"
    identifiers_annotations_path = path_to_identifiers + "column_annotations"

    identifier_annotations = f5[identifiers_annotations_path][...]

    person_id = "person_id"

    slice_person_id = index_annotations(identifier_annotations, person_id)

    person_ids = f5[path_to_identifiers + "core_array"][:, slice_person_id[0]:slice_person_id[1]]

    visit_start = f5[path_to_visit + "core_array"][:, slice_visit_start[0]:slice_visit_start[1]]
    visit_end = f5[path_to_visit + "core_array"][:, slice_visit_end[0]:slice_visit_end[1]]

    visit_concept_slices = visit_annotations[:, slice_visit_concept_name[0]:slice_visit_concept_name[1]]

    visit_concepts = f5[path_to_visit + "core_array"][:, slice_visit_concept_name[0]:slice_visit_concept_name[1]]

    number_of_visits, number_of_categories = visit_concepts.shape

    last_person_id = int(person_ids[0, 0])

    starting_new_position = 0
    person_dict = {}
    for i in range(person_ids.shape[0]):
        person_id = int(person_ids[i, 0])

        if person_id != last_person_id:
            person_dict[last_person_id] = (starting_new_position, i-1)
            starting_new_position = i
            last_person_id = person_id

    person_dict[person_id] = (starting_new_position + 1, i)
    # Now iterate for each person

    has_future_visit_array = np.zeros(shape=(number_of_visits, number_of_categories))
    future_visit_positions_array = np.zeros(shape=(number_of_visits, number_of_categories))
    future_visits_days_array = np.zeros(shape=(number_of_visits, number_of_categories))

    for person_id in person_dict:
        person_start, person_end = person_dict[person_id]

        for i in range(person_end - person_start):
            person_start_i = person_start + i
            future_visit_count = np.sum(visit_concepts[person_start_i + 1: person_end + 1], 0)
            future_visit_count[future_visit_count > 0] = 1
            has_future_visit_array[person_start_i, :] = future_visit_count
            future_visits = visit_concepts[person_start_i + 1: person_end + 1]

            for c in range(number_of_categories):
                future_visit_positions = np.where(future_visits[:, c] > 0)
                if len(future_visit_positions[0]):
                    future_visit_positions_array[person_start_i, c] = person_start_i + future_visit_positions[0][0] + 1

            current_visit_end = visit_end[person_start_i]

            for c in range(number_of_categories):
                if future_visit_positions_array[person_start_i, c] > 0:
                    future_visits_days_array[person_start_i, c] = visit_start[future_visit_positions_array[person_start_i, c]] - \
                                                                  current_visit_end

    # 30 day readmission
    day_30_positions_array = np.zeros(shape=(number_of_visits, number_of_categories))
    day_30_positions_array[np.where((future_visits_days_array >= 1) & (future_visits_days_array <= 30))] = 1

    f5["/computed/next/30_days/visit_occurrence/core_array"] = day_30_positions_array
    f5["/computed/next/30_days/visit_occurrence/column_annotations"] = visit_concept_slices

    f5["/computed/next/days/visit_occurrence/core_array"] = future_visits_days_array
    f5["/computed/next/days/visit_occurrence/column_annotations"] = visit_concept_slices

    f5["/computed/next/has/visit_occurrence/core_array"] = has_future_visit_array
    f5["/computed/next/has/visit_occurrence/column_annotations"] = visit_concept_slices

    f5["/computed/next/position/visit_occurrence/core_array"] = future_visit_positions_array
    f5["/computed/next/position/visit_occurrence/column_annotations"] = visit_concept_slices

if __name__ == "__main__":

    arg_parse_obj = argparse.ArgumentParser(description="A script for adding next visit details into the HDF5 file " +
                                                        "container for data mapped from OHDSI")

    arg_parse_obj.add_argument("-f", dest="hdf5_file_name")
    arg_obj = arg_parse_obj.parse_args()

    main(arg_obj.hdf5_file_name, make_backup=True)