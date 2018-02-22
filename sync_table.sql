-- Function: public.sync_table(character varying, character varying, character varying)

-- DROP FUNCTION public.sync_table(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION public.sync_table(
    src_table_name character varying,
    dst_table_name character varying,
    pk_col_name character varying)
  RETURNS character varying AS
$BODY$
declare
	src_row record;
	dst_row record;
	src_row_arr text[];
	dst_row_arr text[];
	src_pk_val bigint;
	dst_pk_val bigint;
	src_hash varchar;
	dst_hash varchar;
	src refcursor;
	dst refcursor;
	state integer;
	dst_col_names varchar[];
	tmp_col varchar;
	update_list varchar;
	insert_count integer;
	update_count integer;
	delete_count integer;
begin

	open src for execute 'select '||pk_col_name||', md5(('||src_table_name||'.*)::text) from '||src_table_name;
	open dst for execute 'select '||pk_col_name||', md5(('||dst_table_name||'.*)::text) from '||dst_table_name;
	select array_agg(attname) into dst_col_names from pg_attribute where attrelid = src_table_name::regclass::oid and attnum > 0;
	state := 0;
	insert_count := 0;
	update_count := 0;
	delete_count := 0;

	loop
		if state = 0 or state = 1 then
			fetch from src into src_row;
		end if;

		if state = 0 or state = 2 then
			fetch from dst into dst_row;
		end if;
		
		if src_row is not NULL and dst_row is not NULL then
		
			src_row_arr := string_to_array(replace(replace(src_row::text, '(','') , ')', ''),',');
			src_pk_val := src_row_arr[1]::bigint;
			src_hash := src_row_arr[2];
			dst_row_arr := string_to_array(replace(replace(dst_row::text, '(',''), ')', ''), ',');
			dst_pk_val := dst_row_arr[1]::bigint;
			dst_hash := dst_row_arr[2];

		if src_pk_val = dst_pk_val then
		
			if src_hash <> dst_hash then
				foreach tmp_col in array dst_col_names loop
					update_list := format('%s %s = A.%s,', update_list, tmp_col, tmp_col);
				end loop;

				update_list = regexp_replace(update_list, '(.*),$', '\1');
				execute format('WITH A AS (SELECT * FROM %s WHERE %s = %s) UPDATE %s B SET %s FROM A WHERE A.%s = B.%s and B.%s = %s', 
				                                    src_table_name, pk_col_name, src_pk_val, dst_table_name, update_list, pk_col_name, pk_col_name, pk_col_name, src_pk_val);
				update_count := update_count + 1;
			end if;

			state := 0;
			continue;
			
		end if;

		if src_pk_val < dst_pk_val then
			execute format('INSERT INTO %s SELECT * FROM %s WHERE %s = %s', dst_table_name, src_table_name, pk_col_name, src_pk_val);
			insert_count := insert_count + 1;
			state := 1;
			continue;
		end if;

		if src_pk_val > dst_pk_val then
			execute format('DELETE FROM %s WHERE %s = %s', dst_table_name, pk_col_name, dst_pk_val);
			delete_count := delete_count + 1;
			state := 2;
			continue;
		end if;

		-- done
		
		elsif src_row is not NULL then
			src_row_arr := string_to_array(replace(replace(src_row::text, '(','') , ')', ''), ',');
			src_pk_val := src_row_arr[1]::bigint;
			src_hash := src_row_arr[2];

			execute format('INSERT INTO %s SELECT * FROM %s WHERE %s = %s', dst_table_name, src_table_name, pk_col_name, src_pk_val);
			insert_count := insert_count + 1;
			state := 1;
			continue;
		elsif dst_row is not NULL then
			dst_row_arr := string_to_array(replace(replace(dst_row::text, '(',''), ')', ''),',');
			dst_pk_val := dst_row_arr[1]::bigint;
			dst_hash := dst_row_arr[2];
			execute format('DELETE FROM %s WHERE %s = %s', dst_table_name, pk_col_name, dst_pk_val);
			delete_count := delete_count + 1;
			state := 2;
			continue;
		end if;
		
		exit when src_row is NULL and dst_row is NULL;

	end loop;

	return format('%s inserts, %s updates, %s deletes', insert_count, update_count, delete_count);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION public.sync_table(character varying, character varying, character varying)
  OWNER TO webradius;
