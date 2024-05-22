drop table if exists department cascade;
drop table if exists courses cascade;
drop table if exists professor cascade;
drop table if exists valid_entry cascade;
drop table if exists course_offers cascade;
drop table if exists student cascade;
drop table if exists student_courses cascade;
drop table if exists student_dept_change cascade;
-- drop table if exists student_dept_change cascade;
-- drop function if exists validate_course_id_format;
-- drop view if exists course_eval;



CREATE TABLE department (
    dept_id CHAR(3) PRIMARY KEY,
    dept_name VARCHAR(40) NOT NULL UNIQUE
);
CREATE TABLE professor (
    professor_id VARCHAR(10) PRIMARY KEY,
    professor_first_name VARCHAR(40) NOT NULL,
    professor_last_name VARCHAR(40) NOT NULL,
    office_number VARCHAR(20),
    contact_number CHAR(10) NOT NULL,
    start_year INTEGER,
    resign_year INTEGER,
    dept_id CHAR(3),
    CHECK (start_year <= resign_year),
    FOREIGN KEY (dept_id) REFERENCES department(dept_id) ON UPDATE CASCADE
);
CREATE TABLE courses (
    course_id CHAR(6) NOT NULL PRIMARY KEY,
    course_name VARCHAR(20) NOT NULL UNIQUE,
    course_desc TEXT,
    credits NUMERIC NOT NULL,
    dept_id CHAR(3),
    CHECK (credits > 0),
    CHECK (SUBSTRING(course_id, 1, 3) = dept_id AND SUBSTRING(course_id, 4) ~ '^\d{3}$'),
    FOREIGN KEY (dept_id) REFERENCES department(dept_id) ON UPDATE CASCADE
);
CREATE TABLE course_offers (
    course_id CHAR(6),
    session VARCHAR(9),
    semester INTEGER NOT NULL,
    professor_id VARCHAR(10),
    capacity INTEGER,
    enrollments INTEGER,
    CHECK (semester = 1 OR semester = 2),
    PRIMARY KEY (course_id, session, semester),
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON UPDATE CASCADE, 
    FOREIGN KEY (professor_id) REFERENCES professor(professor_id) ON UPDATE CASCADE
);
CREATE TABLE student (
    first_name VARCHAR(40) NOT NULL,
    last_name VARCHAR(40),
    student_id CHAR(11) NOT NULL PRIMARY KEY,
    address VARCHAR(100),
    contact_number CHAR(10) NOT NULL UNIQUE, 
    email_id VARCHAR(50) UNIQUE,
    tot_credits INTEGER NOT NULL,
    dept_id CHAR(3),
    CHECK (tot_credits >= 0),
    FOREIGN KEY (dept_id) REFERENCES department(dept_id) ON UPDATE CASCADE
);
-- course id CHAR(6) Primary Key
-- course name VARCHAR(20)
-- course desc TEXT
-- credits NUMERIC
-- dept id ref Table 9 Foreign Key
-- Table 4: courses
-- course id must have first 3 characters as some dept id and next 3 characters must be digits.


-- student id ref Table 3 Foreign Key
-- course id ref Table 6 Foreign Key
-- session ref Table 6 Foreign Key
-- semester ref Table 6 Foreign Key
-- grade NUMERIC

CREATE TABLE student_courses (
    student_id CHAR(11),
    course_id CHAR(6),
    session VARCHAR(9),
    semester INTEGER,
    grade NUMERIC NOT NULL,
    CHECK (grade >= 0 AND grade <= 10),
    CHECK (semester = 1 OR semester = 2),
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON UPDATE CASCADE,
    FOREIGN KEY (course_id,session, semester) REFERENCES course_offers(course_id,session, semester) ON UPDATE CASCADE
);

CREATE TABLE valid_entry (
    dept_id CHAR(3),
    entry_year INTEGER NOT NULL,
    seq_number INTEGER  NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES department(dept_id) ON UPDATE CASCADE
);


-- dept id CHAR(3) Primary Key
-- dept name VARCHAR(40)
-- Table 9: department


-- When a new student is registered, a unique student id is assigned to each student. A student id is a
-- 10-digit unique code, with the first four digits being entry year, the next three characters are dept id,
-- and the last three digits are seq number. When a new student is registered, your schema must validate
-- this entry number with the below conditions:
-- • The entry year and dept id in student id should be a valid entry in valid entry table.
-- • The sequence number should start from 001 for each department (maintained in valid entry table).
-- Thus, the current sequence number is assigned when a new student is registered in a department.
-- Create a trigger with the name of validate student id to validate the student id. If the entry number
-- assigned to a student is not valid, then raise an "invalid" message; else, successfully insert the tuple in
-- the table.


CREATE OR REPLACE FUNCTION validate_student_function () RETURNS TRIGGER 
AS $$
    DECLARE 
        ent_year INTEGER;
        dep_id CHAR(3);
        seq_n INTEGER;
    BEGIN 
        ent_year := SUBSTRING(NEW.student_id, 1, 4);
        dep_id := SUBSTRING(NEW.student_id FROM 5 FOR 3);
        seq_n := CAST(SUBSTRING(NEW.student_id, 8, 3) AS INTEGER);
        IF NOT EXISTS (SELECT 1 FROM valid_entry WHERE valid_entry.dept_id = dep_id AND valid_entry.entry_year = ent_year and valid_entry.seq_number = seq_n ) THEN
            RAISE EXCEPTION 'invalid';
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

-- trigger validate_student_id
CREATE TRIGGER validate_student_id
BEFORE INSERT ON student
FOR EACH ROW EXECUTE FUNCTION validate_student_function();

-- If the above student id is a valid id, you add that student detail in the student table. But do not
-- forget to increase the counter, i.e., seq number in valid entry table after each insert in the student
-- table. Thus, create a trigger with the name, update seq number, which will update the seq number in
-- valid entry table.
-- Example: Once the valid student is inserted in the student table as shown in 19, there should be an
-- update in valid entry table. The correct update based on the above-given instance for valid entry
-- table is shown below:
-- dept id entry year seq number
-- CSZ 2020 2
-- CSY 2024 3
-- Table 21: Valid update in valid entry table

CREATE OR REPLACE FUNCTION update_seq_number_function () RETURNS TRIGGER
AS $$
    BEGIN 
        UPDATE valid_entry
        SET seq_number = seq_number + 1
        WHERE valid_entry.dept_id = NEW.dept_id and valid_entry.entry_year = CAST(SUBSTRING(NEW.student_id, 1, 4) AS INTEGER);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_seq_number 
AFTER INSERT ON student
FOR EACH ROW EXECUTE FUNCTION update_seq_number_function();


CREATE OR REPLACE FUNCTION valid_email_function () RETURNS TRIGGER
AS $$
    DECLARE
        student_dept_id CHAR(3);
        at_pos INTEGER;
        student_e_id TEXT;
        student_e_char TEXT;
        student_e_dept_id_2 CHAR(3);
        student_e_last TEXT;
    BEGIN
        at_pos := POSITION('@' IN NEW.email_id);
        student_dept_id := SUBSTRING(NEW.student_id FROM 5 FOR 3);
        student_e_id := SUBSTRING(NEW.email_id FROM 1 FOR at_pos-1);
        student_e_char := SUBSTRING(NEW.email_id FROM at_pos FOR 1);
        student_e_dept_id_2 := SUBSTRING(NEW.email_id FROM at_pos+1 FOR 3);
        student_e_last := SUBSTRING(NEW.email_id FROM at_pos+4);
        IF student_e_id != NEW.student_id OR student_e_char != '@' OR student_e_dept_id_2 != student_dept_id OR student_e_last != '.iitd.ac.in' THEN
            RAISE EXCEPTION 'invalid';
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER valid_email
BEFORE INSERT ON student
FOR EACH ROW EXECUTE FUNCTION valid_email_function();



--2.1.4
-- (To allow or to not allow change of branch) The Institute management also wants to study the branch
-- change statistics. For this, your schema must include an additional table student dept change in your
-- 6
-- schema that maintains a record of students that have changed their department consisting of old student id,
-- old dept id, new dept id, and new student id (both old dept id and new dept id must be For-
-- eign key referring to department table). Write a single trigger (name log student dept change) that
-- calls a function upon updating the student table. The function should do as follows: Before the update,
-- if the update is changing the student’s department, check if their department was updated before from
-- student dept change table; if yes, raise an exception “Department can be changed only once”
-- (every student can only change their department once). If the department has not changed before and the
-- entry year (entry year can be extracted from student id) is less than 2022, Raise an exception: “Entry
-- year must be >= 2022”. Only students who entered in 2022 or later can change their department.
-- Further, check whether the average grade of the student is > 8.5 or not (from student courses table)
-- if the average grade of the student is <= 8.5 or the student has done no courses so far raise an exception
-- “Low Grade”. If all conditions are met, perform the update, and after the update, insert a row into the
-- student dept change table.
-- Note: While assigning the new student id you have to check the seq number in the valid entry
-- table to assign the valid student id. Also, do not forget to increase the counter, i.e., seq number in
-- valid entry table after updating the student id. Also, you have to update the corresponding valid
-- email id in the student table.



CREATE TABLE student_dept_change (
    old_student_id CHAR(11) PRIMARY KEY,
    old_dept_id CHAR(3),
    new_student_id CHAR(11) UNIQUE,
    new_dept_id CHAR(3),
    FOREIGN KEY (old_dept_id) REFERENCES department(dept_id) ON UPDATE CASCADE,
    FOREIGN KEY (new_dept_id) REFERENCES department(dept_id) ON UPDATE CASCADE  
);

CREATE OR REPLACE FUNCTION log_student_dept_change_function () RETURNS TRIGGER
AS $$
    DECLARE 
        seq INTEGER;
        seq_text TEXT;
		n_student_id TEXT;
		n_email_id TEXT;
		
    BEGIN
        IF NEW.dept_id != OLD.dept_id AND NEW.student_id = OLD.student_id THEN
            IF EXISTS (SELECT 1 FROM student_dept_change WHERE student_dept_change.new_student_id = OLD.student_id) THEN
                RAISE EXCEPTION 'Department can be changed only once';
            END IF;
            IF CAST(SUBSTRING(OLD.student_id FROM 1 FOR 4) AS INTEGER) < 2022 THEN
                RAISE EXCEPTION 'Entry year must be >= 2022';
            END IF;
            IF (SELECT AVG(grade) FROM student_courses WHERE student_courses.student_id = OLD.student_id) <= 8.5 THEN
                RAISE EXCEPTION 'Low Grade';
            END IF;
            seq := (SELECT seq_number FROM valid_entry WHERE valid_entry.dept_id = NEW.dept_id AND valid_entry.entry_year = CAST(SUBSTRING(OLD.student_id FROM 1 FOR 4) AS INTEGER));
			seq_text := LPAD(seq::text, 3, '0');
			n_student_id := SUBSTRING(OLD.student_id FROM 1 FOR 4) || NEW.dept_id || seq_text;
			n_email_id := SUBSTRING(OLD.student_id FROM 1 FOR 4) || NEW.dept_id || seq_text || '@' || NEW.dept_id || '.iitd.ac.in';
			NEW.student_id = n_student_id;
			NEW.email_id = n_email_id;
			
            INSERT INTO student_dept_change VALUES (OLD.student_id, OLD.dept_id, SUBSTRING(OLD.student_id FROM 1 FOR 4) || NEW.dept_id || seq_text, NEW.dept_id);
            UPDATE valid_entry
            SET seq_number = seq_number + 1
            WHERE valid_entry.dept_id = NEW.dept_id and valid_entry.entry_year = CAST(SUBSTRING(OLD.student_id FROM 1 FOR 4) AS INTEGER);
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

-- DROP trigger log_student_dept_change on student;
 
CREATE TRIGGER log_student_dept_change
BEFORE UPDATE ON student
FOR EACH ROW EXECUTE FUNCTION log_student_dept_change_function();




-- 2.2
--2.2.1
CREATE MATERIALIZED VIEW course_eval AS
SELECT sc.course_id, sc.session, sc.semester, COUNT(DISTINCT sc.student_id) AS number_of_students, AVG(sc.grade) AS average_grade, MAX(sc.grade) AS max_grade, MIN(sc.grade) AS min_grade
FROM student_courses sc
GROUP BY sc.course_id, sc.session, sc.semester;

CREATE OR REPLACE FUNCTION refresh_course_eval() RETURNS TRIGGER
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW course_eval;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER refreshs_course_eval
AFTER INSERT OR UPDATE OR DELETE ON student_courses
FOR EACH ROW EXECUTE FUNCTION refresh_course_eval();


--2.2.2
-- Create a trigger which updates the student table’s tot credits column each time an entry is made
-- into the student courses table. Each time an entry for a student pursuing any course is made in the
-- student courses table, the following is expected.
-- Given the entry that is to be inserted into the student courses table, use the course id and the
-- courses table to get the number of credits for that course. Now that you know the credits for this course,
-- update that particular student’s tot credits and add the credits for this new course in the student
-- table


--2.2.2
CREATE OR REPLACE FUNCTION update_tot_credits_function () RETURNS TRIGGER
AS $$
    BEGIN
        UPDATE student
        SET tot_credits = tot_credits + (SELECT credits FROM courses WHERE courses.course_id = NEW.course_id)
        WHERE student.student_id = NEW.student_id;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tot_credits
AFTER INSERT ON student_courses
FOR EACH ROW EXECUTE FUNCTION update_tot_credits_function();


--2.2.3
-- Implement a trigger that ensures that a student is not enrolled in more than 5 courses simultaneously(in
-- the same session and same semester) in the student courses table. Also, check that while adding
-- entries into student courses table, the credit criteria for the student (maximum 60 total credits for
-- every student) should not be exceeded. If the maximum course criteria or the maximum credit criteria are
-- breached, raise an ”invalid” exception; else, continue with the update.
-- Note: You can use the tot credits column from table student.60 is the total credit limit for every student
-- across all records, across all semesters and across all sessions. No student should surpass this limit.


CREATE OR REPLACE FUNCTION validate_student_courses_function () RETURNS TRIGGER
AS $$
    DECLARE 
        num_courses INTEGER;
        credit INTEGER;
        t_credits INTEGER;
    BEGIN
        num_courses := (
            SELECT COUNT(student_courses.course_id)
            FROM student_courses
            WHERE student_courses.student_id = NEW.student_id AND student_courses.session = NEW.session AND student_courses.semester = NEW.semester
            GROUP BY student_courses.student_id, student_courses.session, student_courses.semester
        );
        credit := (
            SELECT credits
            FROM courses 
            WHERE courses.course_id = NEW.course_id
        );
        t_credits := (
            SELECT tot_credits
            FROM student
            WHERE student.student_id = NEW.student_id
        )+credit;

        IF num_courses >= 5 OR t_credits > 60 THEN
            RAISE EXCEPTION 'invalid';
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_student_courses
BEFORE INSERT ON student_courses
FOR EACH ROW EXECUTE FUNCTION validate_student_courses_function();

--2.2.4
-- Assume that we are trying to insert a record into the student courses table. Write a trigger which uses
-- course id as the foreign key and makes sure that any course of 5 credits is taken up by the student in the
-- student’s first year only.(You can know the student’s first year since the student id begins with the year
-- of their admission; compare this with the first four digits of the session of the course, which is usually of
-- the form 2023-2024). If the entry is for a 5-credit course and is not in the first year of the student, Raise an
-- ”invalid” exception; else, insert the entry into the table. Any entry with a course with less than 5 credits
-- should be added.

CREATE OR REPLACE FUNCTION check_course() RETURNS TRIGGER 
AS $$
    DECLARE
        first_year CHAR(4);
        course_year CHAR(4);
        credit INTEGER;
    BEGIN
        first_year = SUBSTRING(NEW.student_id FROM 1 FOR 4);
        course_year = SUBSTRING(NEW.session FROM 1 FOR 4);
        credit = (SELECT credits FROM courses WHERE course_id = NEW.course_id);
        IF credit = 5 AND first_year != course_year THEN
            RAISE EXCEPTION 'invalid';
        END IF;
		RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_course_cr
BEFORE INSERT ON student_courses
FOR EACH ROW EXECUTE FUNCTION check_course();


--2.2.5
-- Create a view student semester summary from student courses table which contains the stu-
-- dent id, session, semester, sgpa, credits. This view stores the students’ details for a semester.
-- Calculate sgpa (as done at IITD) as
-- grade points secured in courses with grade greater than or equal to 5.0
-- earned credits in courses with grade greater than or equal to 5.0
-- where courses and earned credits should correspond to the semester and session. grade points for a course
-- is the product of grade secured in that course and credits of the course as calculated at IITD! You can inter-
-- pret grades greater than or equal to 5 as pass grades. Ignore failed courses from sgpa calculation. The cred-
-- its in the view corresponds to the credits completed (credits of courses with pass grade) in that semester.
-- Whenever a new row is added to student courses table update the student semester summary
-- view, as well as tot credits in student table. Also, add the course only if the credit count doesn’t
-- exceed the limit of 26 per semester. When the grade for a course is updated in the student courses,
-- update the sgpa in the view. When a row is deleted from student courses table, update the credits
-- and sgpa in the view as well as update tot credits in student table.



CREATE MATERIALIZED VIEW student_semester_summary AS
SELECT student_courses.student_id, student_courses.session,student_courses.semester, SUM(student_courses.grade * courses.credits) / SUM(courses.credits) as sgpa, SUM(courses.credits) as credits
FROM student_courses 
JOIN courses ON courses.course_id = student_courses.course_id
WHERE student_courses.grade >= 5
GROUP BY student_courses.student_id, student_courses.session, student_courses.semester;


-- CREATE OR REPLACE FUNCTION refresh_student_semester_summary()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     IF (TG_OP = 'INSERT') THEN
--         IF (SELECT SUM(courses.credits) FROM student_courses 
--         join courses on courses.course_id = student_courses.course_id 
--         WHERE student_id = NEW.student_id AND session = NEW.session AND semester = NEW.semester) 
--         + (select courses.credits from courses where course_id = NEW.course_id) > 26 THEN
--             RAISE EXCEPTION 'Invalid';
--         END IF;
--     END IF;
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;


-- CREATE OR REPLACE TRIGGER update_student_semester_summary_trigger
-- BEFORE INSERT ON student_courses
-- FOR EACH ROW EXECUTE FUNCTION update_student_semester_summary


CREATE OR REPLACE FUNCTION update_student_semester_summary_function1 () RETURNS TRIGGER
AS $$
    DECLARE 
        credits INTEGER;
    BEGIN 
        IF (TG_OP = 'INSERT') THEN
            credits := (SELECT SUM(courses.credits) FROM student_courses 
            join courses on courses.course_id = student_courses.course_id 
            WHERE student_id = NEW.student_id AND session = NEW.session AND semester = NEW.semester
            GROUP BY student_courses.student_id, student_courses.session, student_courses.semester);
            IF credits + (select courses.credits from courses where course_id = NEW.course_id) > 26 THEN
                RAISE EXCEPTION 'Invalid';
            END IF;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER update_student_semester_summary
BEFORE INSERT ON student_courses
FOR EACH ROW EXECUTE FUNCTION update_student_semester_summary_function1();


CREATE OR REPLACE FUNCTION update_student_semester_summary_function2 () RETURNS TRIGGER
AS $$
    BEGIN 
        REFRESH MATERIALIZED VIEW student_semester_summary;
        RETURN NULL;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_student_semester_summary1 
AFTER INSERT OR DELETE OR UPDATE ON student_courses
FOR EACH ROW EXECUTE FUNCTION update_student_semester_summary_function2();

-- CREATE OR REPLACE FUNCTION update_student_semester_summary_function () RETURNS TRIGGER




--2.2.6

-- Write a single trigger on insert into student courses table. Before insertion, check if the capacity of
-- the course is full from the course offers table; if yes raise an “course is full” exception; if it isn’t full,
-- perform the insertion, and after insertion, update the no. of enrollments in the course in course offers
-- table

CREATE OR REPLACE FUNCTION check_capacity_function () RETURNS TRIGGER
AS $$
    DECLARE 
        cap INTEGER;
        enroll INTEGER;
    BEGIN
        cap := (
            SELECT capacity
            FROM course_offers
            WHERE course_offers.course_id = NEW.course_id AND course_offers.session = NEW.session AND course_offers.semester = NEW.semester
        );
        enroll := (
            SELECT enrollments
            FROM course_offers
            WHERE course_offers.course_id = NEW.course_id AND course_offers.session = NEW.session AND course_offers.semester = NEW.semester
        );
        IF enroll >= cap THEN
            RAISE EXCEPTION 'course is full';
        ELSE
            UPDATE course_offers
            SET enrollments = enroll + 1
            WHERE course_offers.course_id = NEW.course_id AND course_offers.session = NEW.session AND course_offers.semester = NEW.semester;
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_capacity
BEFORE INSERT ON student_courses
FOR EACH ROW EXECUTE FUNCTION check_capacity_function();

--2.3

--2.3.1


CREATE OR REPLACE FUNCTION remove_course_function () RETURNS TRIGGER
AS $$ 
    DECLARE
        s_id CHAR(11);
        credit INTEGER;
    BEGIN
        IF TG_OP = 'DELETE' THEN
			FOR s_id IN (SELECT student_id FROM student_courses WHERE student_courses.course_id = OLD.course_id AND student_courses.session = OLD.session AND student_courses.semester = OLD.semester) LOOP
				credit := (SELECT credits FROM courses WHERE courses.course_id = OLD.course_id);
				UPDATE student
				SET tot_credits = tot_credits - credit
				WHERE student.student_id = s_id;
			END LOOP;
            DELETE FROM student_courses
            WHERE student_courses.course_id = OLD.course_id AND student_courses.session = OLD.session AND student_courses.semester = OLD.semester;
        END IF;
        RETURN OLD;
    END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER remove_course
BEFORE DELETE ON course_offers
FOR EACH ROW EXECUTE FUNCTION remove_course_function();


CREATE OR REPLACE FUNCTION check_prof () RETURNS TRIGGER
AS $$
    BEGIN
        IF EXISTS (SELECT 1 FROM courses WHERE courses.course_id = NEW.course_id) AND EXISTS (SELECT 1 FROM professor WHERE professor.professor_id = NEW.professor_id) THEN
            RETURN NEW;
        ELSE
            RAISE EXCEPTION 'invalid';
        END IF;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_prof
BEFORE INSERT ON course_offers
FOR EACH ROW EXECUTE FUNCTION check_prof();

--2.3.2
-- Given an entry that is to be inserted into the course offers table, create a trigger that makes sure that a
-- professor does not teach more than 4 courses in a session. Also make sure that the course is being offered
-- before the associated professor resigns. If in any case the entry is not valid show an ”invalid” message or
-- else insert the entry into the table.



CREATE OR REPLACE FUNCTION check_professor_function () RETURNS TRIGGER
AS $$
    DECLARE 
        num_courses INTEGER;
        r_year INTEGER;
    BEGIN
        num_courses := (
            SELECT COUNT(course_offers.course_id)
            FROM course_offers
            WHERE course_offers.professor_id = NEW.professor_id AND course_offers.session = NEW.session
            GROUP BY course_offers.professor_id, course_offers.session
        );
        r_year := (
            SELECT resign_year
            FROM professor
            WHERE professor.professor_id = NEW.professor_id
        );
        IF num_courses >= 4 OR r_year < CAST(SUBSTRING(NEW.session,1,4) AS INTEGER) THEN
            RAISE EXCEPTION 'invalid';
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_professor
BEFORE INSERT ON course_offers
FOR EACH ROW EXECUTE FUNCTION check_professor_function();
        

--2.4
--2.4.1
-- Write a single trigger using which on update on the department table, if dept id is updated, updates all
-- course ids of the courses belonging to that department according to the new dept id in course offers,
-- courses and student courses tables (i.e update the first three digits of the course id according to new
-- dept id), also update it in professor and student tables. On delete, before deletion, check if there
-- are no students in the department, if there are students show a “Department has students” message, else
-- delete the department record and further delete all courses from course offers, courses tables and
-- professors in that department from professor table.



CREATE OR REPLACE FUNCTION update_department_trigger() 
RETURNS TRIGGER AS $$
DECLARE
    d_name TEXT;
BEGIN
    IF TG_OP = 'UPDATE' THEN
		d_name := (SELECT dept_name FROM department WHERE dept_id = OLD.dept_id);
        IF NEW.dept_id != OLD.dept_id THEN
            INSERT INTO department VALUES (NEW.dept_id, 'text');
            UPDATE student SET dept_id = NEW.dept_id,student_id = SUBSTRING(student_id,1,4) || NEW.dept_id || SUBSTRING(student_id FROM 8),
			email_id = SUBSTRING(student_id,1,4) || NEW.dept_id || SUBSTRING(student_id FROM 8) || '@' || NEW.dept_id || '.iitd.ac.in'
			WHERE dept_id = OLD.dept_id;
            UPDATE courses SET dept_id = NEW.dept_id, course_id = NEW.dept_id || SUBSTRING(course_id FROM 4) WHERE dept_id = OLD.dept_id;
            UPDATE professor SET dept_id = NEW.dept_id WHERE dept_id = OLD.dept_id;
			UPDATE valid_entry SET dept_id = NEW.dept_id WHERE dept_id = OLD.dept_id;
            UPDATE course_offers SET course_id = NEW.dept_id || SUBSTRING(course_id FROM 4) WHERE SUBSTRING(course_id FROM 1 FOR 3) = OLD.dept_id;
            UPDATE student_courses SET course_id = NEW.dept_id || SUBSTRING(course_id FROM 4) WHERE SUBSTRING(course_id FROM 1 FOR 3) = OLD.dept_id;
            --update the student_dept_change table table with the new department name
			
            UPDATE student_dept_change
            SET old_dept_id = NEW.dept_id,old_student_id = SUBSTRING(old_student_id FROM 1 FOR 4) || NEW.dept_id || SUBSTRING(old_student_id FROM 8)
            WHERE old_dept_id = OLD.dept_id;
            UPDATE student_dept_change
			
            SET new_dept_id = NEW.dept_id,new_student_id = SUBSTRING(new_student_id FROM 1 FOR 4) || NEW.dept_id || SUBSTRING(new_student_id FROM 8)
            WHERE new_dept_id = OLD.dept_id;
            DELETE FROM department WHERE dept_id = OLD.dept_id;
            
			UPDATE department SET dept_name = d_name WHERE dept_id = NEW.dept_id;
            RETURN NULL;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF EXISTS (SELECT * FROM student WHERE dept_id = OLD.dept_id) THEN
            RAISE EXCEPTION 'Department has students';
        ELSE
            DELETE FROM course_offers
            WHERE SUBSTRING(course_id,1,3) = OLD.dept_id;
            DELETE FROM student_courses
			WHERE SUBSTRING(course_id,1,3) = OLD.dept_id;
			DELETE FROM courses
            WHERE dept_id = OLD.dept_id;
            DELETE FROM professor
            WHERE dept_id = OLD.dept_id;
			DELETE FROM valid_entry
			WHERE dept_id = OLD.dept_id;
			
			
			DELETE FROM student_dept_change
			WHERE old_dept_id = OLD.dept_id;
			
			DELETE FROM student_dept_change
			WHERE new_dept_id = OLD.dept_id;
			
			
        END IF;
		RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- drop trigger update_department_trigger on department;

CREATE TRIGGER update_department_trigger
BEFORE UPDATE OR DELETE ON department
FOR EACH ROW
EXECUTE FUNCTION update_department_trigger();