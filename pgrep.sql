CREATE OR REPLACE FUNCTION public.pgrep(
    tablename_pattern character varying,
    row_pattern character varying,
    limit_rows integer)
  RETURNS SETOF record AS
$BODY$
declare
	r record;
	result record;
	tablename varchar;
	query varchar;
begin

	for tablename in select nspname||'.'||relname from pg_class a, pg_namespace b where a.relnamespace = b.oid and relname ilike tablename_pattern and relkind = 'r' loop
		query := 'select * from '||tablename;

		if limit_rows > 0 then
			query := query || ' limit '||limit_rows;
		end if;

		for r in execute query loop
			if r::varchar ilike row_pattern then
				result := row(tablename, r::varchar);
				return next result;
			end if;
		end loop;
	end loop;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
