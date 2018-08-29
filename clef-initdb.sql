DROP SCHEMA IF EXISTS clef;
CREATE SCHEMA IF NOT EXISTS clef CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE clef;

DROP TABLE IF EXISTS composers;
DROP TABLE IF EXISTS eras;
DROP TABLE IF EXISTS work_type;
DROP TABLE IF EXISTS works;
DROP TABLE IF EXISTS dataset_contents;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS tag_relations;

/**** TABLES ****/

/*
Table to track composer metadata.

Composer name must be unique.

@since 1.0.0
*/
CREATE TABLE IF NOT EXISTS composers (
	id SMALLINT PRIMARY KEY AUTO_INCREMENT,
    composer_name VARCHAR(100) NOT NULL UNIQUE,
    born INT(4),
    died INT(4)
) ENGINE = InnoDB;


/*
Table to track era metadata.

Era here refers to designations like "Baroque" or "Romantic". Maybe not the most accurate 
terminology, but it's widely used and generally widely understood.

@since 1.0.0
*/
CREATE TABLE IF NOT EXISTS eras (
	id SMALLINT PRIMARY KEY AUTO_INCREMENT,
    era VARCHAR(50) UNIQUE
) ENGINE = InnoDB;


/*
Table to track work type metadata. 

Work type here refers to composition type or genre, e.g. "sonata" or "symphony"

@since 1.0.0
*/
CREATE TABLE IF NOT EXISTS work_type (
	id SMALLINT PRIMARY KEY AUTO_INCREMENT,
    work_type VARCHAR(50) NOT NULL UNIQUE
) ENGINE = InnoDB;



/*
Table to track all files in all datasets.

Note that the combination of dataset_name and filename must be unique -- that is to say, 
filenames must be unique within each dataset.

@since 1.0.0
*/
CREATE TABLE IF NOT EXISTS dataset_contents (
	id BIGINT PRIMARY KEY AUTO_INCREMENT,
    collection VARCHAR(50) NOT NULL,
    dataset_name VARCHAR(50) NOT NULL,
    filename VARCHAR(50) NOT NULL,
    UNIQUE KEY dset_index ( dataset_name, filename )
) ENGINE = InnoDB;


/*
Table to track tags.

@since 1.0.0
*/
CREATE TABLE IF NOT EXISTS tags (
	id SMALLINT PRIMARY KEY AUTO_INCREMENT,
    tag VARCHAR(50) NOT NULL UNIQUE
) ENGINE = InnoDB;


/*
Table to track work metadata.

Currently, it is assumed that there is a 1:1 relationship between works and filenames, 
i.e., each file in dataset_contents contains exactly one work. This will likely change
later in order to accommodate scenarios in which a file only represents a piece of a work, 
e.g. a movement, or in which a file contains multiple works (this seems more unlikely).

@since 1.0.0
*/
CREATE TABLE IF NOT EXISTS works (
	id MEDIUMINT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    catalog VARCHAR(50),
    catalog_number VARCHAR(50),
    pcn VARCHAR(50),
    composer_id SMALLINT NOT NULL, FOREIGN KEY ( composer_id ) REFERENCES composers ( id ) ON DELETE CASCADE,
    era_id SMALLINT, FOREIGN KEY ( era_id ) REFERENCES eras ( id ) ON DELETE CASCADE,
    work_type_id SMALLINT, FOREIGN KEY ( work_type_id ) REFERENCES work_type ( id ) ON DELETE CASCADE,
    dataset_contents_id BIGINT NOT NULL, FOREIGN KEY ( dataset_contents_id ) REFERENCES dataset_contents ( id ) ON DELETE CASCADE,
    UNIQUE KEY works_index ( title, composer_id, dataset_contents_id )
) ENGINE = InnoDB;


/*
Table to associate tags with works. Note that only unique associations of a given tag with a given work 
are permitted.

@since 1.0.0
*/
CREATE TABLE IF NOT EXISTS tag_relations (
	id SMALLINT PRIMARY KEY AUTO_INCREMENT,
    work_id MEDIUMINT NOT NULL, FOREIGN KEY ( work_id ) REFERENCES works ( id ) ON DELETE CASCADE,
    tag_id  SMALLINT NOT NULL, FOREIGN KEY ( tag_id ) REFERENCES tags ( id ) ON DELETE CASCADE,
	UNIQUE KEY tag_rel_index ( work_id, tag_id )
) ENGINE = InnoDB;



/**** PROCEDURES ****/
DELIMITER $$

	DROP PROCEDURE IF EXISTS getJoinedMetadata $$
	#
    # https://forums.mysql.com/read.php?10,635524,635529#msg-635529
    #
	CREATE PROCEDURE getJoinedMetadata ( IN dset_names VARCHAR(500), IN filenames VARCHAR(500) )
    BEGIN
		
        # 1. Create a temp table for the dataset names
        DROP TABLE IF EXISTS temp_dsets;
        CREATE TABLE temp_dsets ( txt VARCHAR(500) );
        INSERT INTO temp_dsets VALUES ( dset_names );
        SELECT GROUP_CONCAT(DISTINCT txt) INTO @dsetData FROM temp_dsets;
        
        DROP TEMPORARY TABLE IF EXISTS dsets;
        CREATE TEMPORARY TABLE dsets ( val VARCHAR(500) );
        SET @dset_sql = CONCAT( "INSERT INTO dsets ( val ) VALUES ('", REPLACE(@dsetData, ",", "'),('"),"');");
        PREPARE dsetStmt FROM @dset_sql;
        EXECUTE dsetStmt;
        
        # 2. Create a temp table for the filenames
        
        DROP TABLE IF EXISTS temp_fnames;
        CREATE TABLE temp_fnames ( txt VARCHAR(500) );
        INSERT INTO temp_fnames VALUES ( filenames );
        SELECT GROUP_CONCAT(DISTINCT txt) INTO @fnameData FROM temp_fnames;
        
        DROP TEMPORARY TABLE IF EXISTS fnames;
        CREATE TEMPORARY TABLE fnames ( val VARCHAR(500) );
		SET @fname_sql = CONCAT( "INSERT INTO fnames ( val ) VALUES ('", REPLACE(@fnameData, ",", "'),('"),"');");
		PREPARE fnameStmt FROM @fname_sql;
        EXECUTE fnameStmt;
        
        # 3. Get the data using the temp tables for the IN clauses
        
		SELECT  DC.collection AS collection,
				DC.dataset_name AS dataset_name,
				DC.filename AS filename,
                W.title AS title,
                W.catalog AS catalog,
                W.catalog_number AS catalog_number,
                W.pcn AS pcn,
                C.composer_name AS composer_name,
                C.born AS born,
                C.died AS died,
                WT.work_type AS work_type,
                E.era AS era,
                T.tag AS tag
        
        FROM works W
        
        INNER JOIN composers C 			ON C.id = W.composer_id
        INNER JOIN dataset_contents DC 	ON DC.id = W.dataset_contents_id
        LEFT  JOIN eras E 				ON E.id = W.era_id
        LEFT  JOIN work_type WT 		ON WT.id = W.work_type_id
        LEFT  JOIN tag_relations TR 	ON TR.work_id = W.id
        INNER JOIN tags T 				ON T.id = TR.tag_id
        
        WHERE DC.dataset_name IN ( SELECT DISTINCT val FROM dsets ) AND DC.filename IN ( SELECT DISTINCT val FROM fnames );
        
    END
    
$$
DELIMITER ;