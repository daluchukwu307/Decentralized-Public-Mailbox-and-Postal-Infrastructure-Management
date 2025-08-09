;; Mail Forwarding Coordination Contract
;; Processes address changes and mail redirection services

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-INPUT (err u501))
(define-constant ERR-FORWARDING-NOT-FOUND (err u502))
(define-constant ERR-INVALID-STATE (err u503))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u504))

;; Data structures
(define-map forwarding-requests
  { request-id: uint }
  {
    customer: principal,
    old-address: {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int},
    new-address: {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int},
    start-date: uint,
    end-date: uint,
    forwarding-type: (string-ascii 20),
    status: (string-ascii 20),
    fee-paid: uint,
    created-at: uint,
    approved-at: (optional uint)
  }
)

(define-map forwarding-records
  { record-id: uint }
  {
    request-id: uint,
    mail-piece-id: (string-ascii 50),
    original-address: {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int},
    forwarded-to: {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int},
    forwarded-date: uint,
    mail-type: (string-ascii 30),
    carrier: principal,
    delivery-status: (string-ascii 20)
  }
)

(define-map address-validations
  { validation-id: uint }
  {
    address: {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int},
    validated-by: principal,
    validation-date: uint,
    is-valid: bool,
    validation-notes: (string-ascii 200)
  }
)

(define-map forwarding-fees
  { fee-type: (string-ascii 20) }
  {
    base-fee: uint,
    monthly-fee: uint,
    processing-fee: uint,
    active: bool
  }
)

;; Data variables
(define-data-var next-request-id uint u1)
(define-data-var next-record-id uint u1)
(define-data-var next-validation-id uint u1)
(define-data-var total-forwarding-requests uint u0)
(define-data-var total-revenue uint u0)

;; Initialize forwarding fees
(map-set forwarding-fees { fee-type: "temporary" } { base-fee: u1000, monthly-fee: u500, processing-fee: u100, active: true })
(map-set forwarding-fees { fee-type: "permanent" } { base-fee: u2000, monthly-fee: u0, processing-fee: u200, active: true })
(map-set forwarding-fees { fee-type: "premium" } { base-fee: u3000, monthly-fee: u1000, processing-fee: u300, active: true })

;; Public functions

;; Submit forwarding request
(define-public (submit-forwarding-request
  (old-address {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int})
  (new-address {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int})
  (start-date uint)
  (end-date uint)
  (forwarding-type (string-ascii 20))
  (payment uint))
  (let (
    (request-id (var-get next-request-id))
    (fee-info (unwrap! (map-get? forwarding-fees { fee-type: forwarding-type }) ERR-INVALID-INPUT))
    (duration-months (/ (- end-date start-date) u4320)) ;; Approximate blocks per month
    (total-fee (+ (get base-fee fee-info)
                  (get processing-fee fee-info)
                  (* (get monthly-fee fee-info) duration-months)))
  )
    (asserts! (< (len (get street old-address)) u101) ERR-INVALID-INPUT)
    (asserts! (< (len (get city old-address)) u51) ERR-INVALID-INPUT)
    (asserts! (< (len (get street new-address)) u101) ERR-INVALID-INPUT)
    (asserts! (< (len (get city new-address)) u51) ERR-INVALID-INPUT)
    (asserts! (> end-date start-date) ERR-INVALID-INPUT)
    (asserts! (>= start-date block-height) ERR-INVALID-INPUT)
    (asserts! (< (len forwarding-type) u21) ERR-INVALID-INPUT)
    (asserts! (get active fee-info) ERR-INVALID-INPUT)
    (asserts! (>= payment total-fee) ERR-INSUFFICIENT-PAYMENT)

    (map-set forwarding-requests
      { request-id: request-id }
      {
        customer: tx-sender,
        old-address: old-address,
        new-address: new-address,
        start-date: start-date,
        end-date: end-date,
        forwarding-type: forwarding-type,
        status: "pending",
        fee-paid: payment,
        created-at: block-height,
        approved-at: none
      }
    )

    (var-set next-request-id (+ request-id u1))
    (var-set total-forwarding-requests (+ (var-get total-forwarding-requests) u1))
    (var-set total-revenue (+ (var-get total-revenue) payment))

    (ok request-id)
  )
)

;; Approve forwarding request
(define-public (approve-forwarding-request (request-id uint))
  (let ((request (unwrap! (map-get? forwarding-requests { request-id: request-id }) ERR-FORWARDING-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status request) "pending") ERR-INVALID-STATE)

    (map-set forwarding-requests
      { request-id: request-id }
      (merge request {
        status: "approved",
        approved-at: (some block-height)
      })
    )

    (ok true)
  )
)

;; Process mail forwarding
(define-public (process-mail-forwarding
  (request-id uint)
  (mail-piece-id (string-ascii 50))
  (mail-type (string-ascii 30)))
  (let (
    (request (unwrap! (map-get? forwarding-requests { request-id: request-id }) ERR-FORWARDING-NOT-FOUND))
    (record-id (var-get next-record-id))
  )
    (asserts! (is-eq (get status request) "approved") ERR-INVALID-STATE)
    (asserts! (>= block-height (get start-date request)) ERR-INVALID-STATE)
    (asserts! (<= block-height (get end-date request)) ERR-INVALID-STATE)
    (asserts! (< (len mail-piece-id) u51) ERR-INVALID-INPUT)
    (asserts! (< (len mail-type) u31) ERR-INVALID-INPUT)

    (map-set forwarding-records
      { record-id: record-id }
      {
        request-id: request-id,
        mail-piece-id: mail-piece-id,
        original-address: (get old-address request),
        forwarded-to: (get new-address request),
        forwarded-date: block-height,
        mail-type: mail-type,
        carrier: tx-sender,
        delivery-status: "forwarded"
      }
    )

    (var-set next-record-id (+ record-id u1))

    (ok record-id)
  )
)

;; Validate address
(define-public (validate-address
  (address {street: (string-ascii 100), city: (string-ascii 50), zip: uint, lat: int, lng: int})
  (is-valid bool)
  (validation-notes (string-ascii 200)))
  (let ((validation-id (var-get next-validation-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (< (len (get street address)) u101) ERR-INVALID-INPUT)
    (asserts! (< (len (get city address)) u51) ERR-INVALID-INPUT)
    (asserts! (< (len validation-notes) u201) ERR-INVALID-INPUT)

    (map-set address-validations
      { validation-id: validation-id }
      {
        address: address,
        validated-by: tx-sender,
        validation-date: block-height,
        is-valid: is-valid,
        validation-notes: validation-notes
      }
    )

    (var-set next-validation-id (+ validation-id u1))

    (ok validation-id)
  )
)

;; Update forwarding status
(define-public (update-forwarding-status (request-id uint) (new-status (string-ascii 20)))
  (let ((request (unwrap! (map-get? forwarding-requests { request-id: request-id }) ERR-FORWARDING-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get customer request))) ERR-NOT-AUTHORIZED)
    (asserts! (< (len new-status) u21) ERR-INVALID-INPUT)

    (map-set forwarding-requests
      { request-id: request-id }
      (merge request { status: new-status })
    )

    (ok true)
  )
)

;; Update delivery status
(define-public (update-delivery-status (record-id uint) (new-status (string-ascii 20)))
  (let ((record (unwrap! (map-get? forwarding-records { record-id: record-id }) ERR-INVALID-INPUT)))
    (asserts! (is-eq tx-sender (get carrier record)) ERR-NOT-AUTHORIZED)
    (asserts! (< (len new-status) u21) ERR-INVALID-INPUT)

    (map-set forwarding-records
      { record-id: record-id }
      (merge record { delivery-status: new-status })
    )

    (ok true)
  )
)

;; Update forwarding fees
(define-public (update-forwarding-fees
  (fee-type (string-ascii 20))
  (base-fee uint)
  (monthly-fee uint)
  (processing-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (< (len fee-type) u21) ERR-INVALID-INPUT)

    (map-set forwarding-fees
      { fee-type: fee-type }
      {
        base-fee: base-fee,
        monthly-fee: monthly-fee,
        processing-fee: processing-fee,
        active: true
      }
    )

    (ok true)
  )
)

;; Read-only functions

;; Get forwarding request
(define-read-only (get-forwarding-request (request-id uint))
  (map-get? forwarding-requests { request-id: request-id })
)

;; Get forwarding record
(define-read-only (get-forwarding-record (record-id uint))
  (map-get? forwarding-records { record-id: record-id })
)

;; Get address validation
(define-read-only (get-address-validation (validation-id uint))
  (map-get? address-validations { validation-id: validation-id })
)

;; Get forwarding fees
(define-read-only (get-forwarding-fees (fee-type (string-ascii 20)))
  (map-get? forwarding-fees { fee-type: fee-type })
)

;; Get total forwarding requests
(define-read-only (get-total-forwarding-requests)
  (var-get total-forwarding-requests)
)

;; Get total revenue
(define-read-only (get-total-revenue)
  (var-get total-revenue)
)

;; Calculate forwarding fee
(define-read-only (calculate-forwarding-fee (forwarding-type (string-ascii 20)) (duration-months uint))
  (match (map-get? forwarding-fees { fee-type: forwarding-type })
    fee-info (ok (+ (get base-fee fee-info)
                    (get processing-fee fee-info)
                    (* (get monthly-fee fee-info) duration-months)))
    ERR-INVALID-INPUT
  )
)
