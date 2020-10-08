# Notes

## 2019-10-31
Changing the item location lable is changing to print `BR` and will say:
 `Floating` whenever the item location "starts with" `ts`

 
## 2020-08-21
Modified the template `replace.html.ep` to include a select that has options for a pre-generated list of locations.

To refresh the list, use this SQL generate location codes and names:

```sql
WITH locations AS (
	SELECT DISTINCT
	s.location_code AS location_code

	FROM
	sierra_view.statistic_group_myuser as s
)

SELECT
c.location_code,
n.name

FROM
locations as c

LEFT OUTER JOIN
sierra_view.location as l
ON
  l.code = c.location_code

LEFT OUTER JOIN
sierra_view.location_name as n
ON
  n.location_id = l.id

WHERE
n.name !~* '(^do not use)|(^.*window$)|(^.*locker$)'


-- Also, include an extra locations that don't come from Sierra
UNION ALL
SELECT
'ils',
'ILS Department'

order by
location_code
```
