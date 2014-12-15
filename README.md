db-minicore
===========

DB Mini Core is a set of general database object for MS SQL.


Mini Core Versions
------------------

Some of the stuff in DB-CORE is totally general meaning its not related to games and that stuff can benefit everyone thats developing/administrating databases. Adding update scripts to create a few mini core versions so that more developers/administrators can benefit from the DB-CORE code.

All the mini core versions are zero point something, which relates to them only being part of the whole DB-CORE thing.

 CORA.A is the absolute minimum (zsystem.settings and zsystem.versions)
 CORE.B adds the zdm schema
 CORE.C adds the zutil schema
 CORE.D adds role zzp_server, zsystem.Settings procs, zsystem.events and zsystem.texts
 CORE.J adds all kinds of other stuff (f.e. identities, tasks, jobs, lookup tables and metrics)

See full list of objects below.  Also check out the blog Are you using Mini Core to your benefit?

The reason for jumping from D to J is that we want to be able to create more versions if needed. If someone f.e. wants CORE.D plus a few objects from zsystem but not all in CORE.J we would create CORE.E with that stuff.

So the idea is that every now and then (not very often, maybe 1-4 times a year) we go over new DB-CORE updates and see if there have been any changes in objects that are part of mini core and add new mini core updates as needed.
