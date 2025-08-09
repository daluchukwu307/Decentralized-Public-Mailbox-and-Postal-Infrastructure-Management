;; Mail Slot Installation Oversight Contract
;; Manages installation of mail slots in residential and commercial buildings

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-INPUT (err u201))
(define-constant ERR-INSTALLATION-NOT-FOUND (err u202))
(define-constant ERR-INVALID-STATE (err u203))

;; Data structures
(define-map installation-requests
  { request-id: uint }
  {
    location: {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int},
    building-type: (string-ascii 20),
    requested-by: principal,
    requested-at: uint,
    approved-at: (optional uint),
    assigned-contractor: (optional principal),
    installation-date: (optional uint),
    completed-at: (optional uint),
    cost: uint,
    status: (string-ascii 20),
    slot-type: (string-ascii 30)
  }
)

(define-map contractors
  { contractor: principal }
  {
    name: (string-ascii 50),
    license-number: (string-ascii 30),
    rating: uint,
    installations-completed: uint,
    active: bool
  }
)

(define-map installations
  { installation-id: uint }
  {
    request-id: uint,
    location: {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int},
    slot-specifications: (string-ascii 200),
    contractor: principal,
    installation-date: uint,
    inspection-passed: bool,
    warranty-expires: uint
  }
)

;; Data variables
(define-data-var next-request-id uint u1)
(define-data-var next-installation-id uint u1)
(define-data-var total-installations uint u0)

;; Public functions

;; Request mail slot installation
(define-public (request-installation
  (location {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int})
  (building-type (string-ascii 20))
  (slot-type (string-ascii 30)))
  (let ((request-id (var-get next-request-id)))
    (asserts! (< (len (get street location)) u101) ERR-INVALID-INPUT)
    (asserts! (< (len (get city location)) u51) ERR-INVALID-INPUT)
    (asserts! (< (len building-type) u21) ERR-INVALID-INPUT)
    (asserts! (< (len slot-type) u31) ERR-INVALID-INPUT)

    (map-set installation-requests
      { request-id: request-id }
      {
        location: location,
        building-type: building-type,
        requested-by: tx-sender,
        requested-at: block-height,
        approved-at: none,
        assigned-contractor: none,
        installation-date: none,
        completed-at: none,
        cost: u0,
        status: "pending",
        slot-type: slot-type
      }
    )

    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Register contractor
(define-public (register-contractor (name (string-ascii 50)) (license-number (string-ascii 30)))
  (begin
    (asserts! (< (len name) u51) ERR-INVALID-INPUT)
    (asserts! (< (len license-number) u31) ERR-INVALID-INPUT)

    (map-set contractors
      { contractor: tx-sender }
      {
        name: name,
        license-number: license-number,
        rating: u5,
        installations-completed: u0,
        active: true
      }
    )

    (ok true)
  )
)

;; Approve installation request
(define-public (approve-installation-request (request-id uint))
  (let ((request (unwrap! (map-get? installation-requests { request-id: request-id }) ERR-INSTALLATION-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "pending") ERR-INVALID-STATE)

    (map-set installation-requests
      { request-id: request-id }
      (merge request {
        approved-at: (some block-height),
        status: "approved"
      })
    )

    (ok true)
  )
)

;; Assign contractor to installation
(define-public (assign-contractor (request-id uint) (contractor principal) (estimated-cost uint))
  (let (
    (request (unwrap! (map-get? installation-requests { request-id: request-id }) ERR-INSTALLATION-NOT-FOUND))
    (contractor-info (unwrap! (map-get? contractors { contractor: contractor }) ERR-INVALID-INPUT))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "approved") ERR-INVALID-STATE)
    (asserts! (get active contractor-info) ERR-INVALID-INPUT)

    (map-set installation-requests
      { request-id: request-id }
      (merge request {
        assigned-contractor: (some contractor),
        cost: estimated-cost,
        status: "assigned"
      })
    )

    (ok true)
  )
)

;; Schedule installation
(define-public (schedule-installation (request-id uint) (installation-date uint))
  (let ((request (unwrap! (map-get? installation-requests { request-id: request-id }) ERR-INSTALLATION-NOT-FOUND)))
    (asserts! (is-eq (some tx-sender) (get assigned-contractor request)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "assigned") ERR-INVALID-STATE)
    (asserts! (> installation-date block-height) ERR-INVALID-INPUT)

    (map-set installation-requests
      { request-id: request-id }
      (merge request {
        installation-date: (some installation-date),
        status: "scheduled"
      })
    )

    (ok true)
  )
)

;; Complete installation
(define-public (complete-installation
  (request-id uint)
  (slot-specifications (string-ascii 200))
  (inspection-passed bool))
  (let (
    (request (unwrap! (map-get? installation-requests { request-id: request-id }) ERR-INSTALLATION-NOT-FOUND))
    (installation-id (var-get next-installation-id))
    (contractor (unwrap! (get assigned-contractor request) ERR-INVALID-STATE))
    (contractor-info (unwrap! (map-get? contractors { contractor: contractor }) ERR-INVALID-INPUT))
  )
    (asserts! (is-eq tx-sender contractor) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "scheduled") ERR-INVALID-STATE)
    (asserts! (< (len slot-specifications) u201) ERR-INVALID-INPUT)

    ;; Update request
    (map-set installation-requests
      { request-id: request-id }
      (merge request {
        completed-at: (some block-height),
        status: "completed"
      })
    )

    ;; Create installation record
    (map-set installations
      { installation-id: installation-id }
      {
        request-id: request-id,
        location: (get location request),
        slot-specifications: slot-specifications,
        contractor: contractor,
        installation-date: block-height,
        inspection-passed: inspection-passed,
        warranty-expires: (+ block-height u52560) ;; ~1 year in blocks
      }
    )

    ;; Update contractor stats
    (map-set contractors
      { contractor: contractor }
      (merge contractor-info {
        installations-completed: (+ (get installations-completed contractor-info) u1)
      })
    )

    (var-set next-installation-id (+ installation-id u1))
    (var-set total-installations (+ (var-get total-installations) u1))

    (ok installation-id)
  )
)

;; Update contractor rating
(define-public (update-contractor-rating (contractor principal) (new-rating uint))
  (let ((contractor-info (unwrap! (map-get? contractors { contractor: contractor }) ERR-INVALID-INPUT)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rating u5) ERR-INVALID-INPUT)
    (asserts! (> new-rating u0) ERR-INVALID-INPUT)

    (map-set contractors
      { contractor: contractor }
      (merge contractor-info { rating: new-rating })
    )

    (ok true)
  )
)

;; Read-only functions

;; Get installation request
(define-read-only (get-installation-request (request-id uint))
  (map-get? installation-requests { request-id: request-id })
)

;; Get contractor info
(define-read-only (get-contractor (contractor principal))
  (map-get? contractors { contractor: contractor })
)

;; Get installation details
(define-read-only (get-installation (installation-id uint))
  (map-get? installations { installation-id: installation-id })
)

;; Get total installations
(define-read-only (get-total-installations)
  (var-get total-installations)
)

;; Get next request ID
(define-read-only (get-next-request-id)
  (var-get next-request-id)
)
