SELECT
  b.id,
  b."startTime",
  b."endTime",
  b.status,
  b."userId",
  b."eventTypeId",
  b.id AS "bookingId",
  u.email AS "userEmail",
  et.title AS "eventTypeName",
  et."teamId",
  (
    EXTRACT(
      epoch
      FROM
        (b."endTime" - b."startTime")
    ) / (60) :: numeric
  ) AS length,
  b.title AS "bookingTitle",
  b.description AS "bookingDescription",
  b.location AS "bookingLocation",
  b.paid AS "isPaid",
  b.rescheduled AS "isRescheduled",
  b."isRecorded",
  b.rating AS "bookingRating",
  b."ratingFeedback" AS "bookingRatingFeedback",
  b."cancellationReason",
  b."rejectionReason",
  b."fromReschedule",
  b."dynamicEventSlugRef",
  b."dynamicGroupSlugRef",
  b."recurringEventId",
  b."customInputs",
  b."smsReminderNumber",
  b."destinationCalendarId",
  b.metadata,
  b.responses,
  b."iCalSequence",
  b."iCalUID",
  b."userPrimaryEmail",
  b."idempotencyKey",
  b."noShowHost",
  b."cancelledBy",
  b."rescheduledBy",
  b."oneTimePassword",
  b."reassignReason",
  b."reassignById",
  b."creationSource",
  b.uid AS "bookingUid",
  b."createdAt",
  b."updatedAt"
FROM
  (
    (
      "Booking" b
      LEFT JOIN users u ON ((b."userId" = u.id))
    )
    LEFT JOIN "EventType" et ON ((b."eventTypeId" = et.id))
  );