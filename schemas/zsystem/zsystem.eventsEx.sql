
IF OBJECT_ID('zsystem.eventsEx') IS NOT NULL
  DROP VIEW zsystem.eventsEx
GO
CREATE VIEW zsystem.eventsEx
AS
  SELECT E.eventID, E.eventDate, E.eventTypeID, ET.eventTypeName, E.taskID, T.taskName, fixedText = X.[text], E.eventText,
         E.duration, E.referenceID, E.parentID, E.nestLevel,
         E.date_1, E.int_1, E.int_2, E.int_3, E.int_4, E.int_5, E.int_6, E.int_7, E.int_8, E.int_9
    FROM zsystem.events E
      LEFT JOIN zsystem.eventTypes ET ON ET.eventTypeID = E.eventTypeID
      LEFT JOIN zsystem.tasks T ON T.taskID = E.taskID
      LEFT JOIN zsystem.texts X ON X.textID = E.textID
GO
GRANT SELECT ON zsystem.eventsEx TO zzp_server
GO
