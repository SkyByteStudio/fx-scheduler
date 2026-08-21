const run = $json;

const escapeHtml = (value) =>
  String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

const number = (
  value,
  minimumFractionDigits = 0,
  maximumFractionDigits = 2,
) => {
  if (value === null || value === undefined || value === '') {
    return '—';
  }

  const numericValue = Number(value);

  if (!Number.isFinite(numericValue)) {
    return escapeHtml(value);
  }

  return numericValue.toLocaleString('en-GB', {
    minimumFractionDigits,
    maximumFractionDigits,
  });
};

const money = (value) => number(value, 2, 2);

const percentage = (value) => {
  if (value === null || value === undefined || value === '') {
    return '—';
  }

  return `${number(value, 2, 2)}%`;
};

const formatDate = (value) => {
  if (!value) {
    return '—';
  }

  const parsed = new Date(`${value}T00:00:00`);

  if (Number.isNaN(parsed.getTime())) {
    return escapeHtml(value);
  }

  return parsed.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  });
};

const assignments = Array.isArray(run.assignments)
  ? run.assignments
  : [];

const metrics = Array.isArray(run.metrics)
  ? run.metrics
  : [];

const permanentAssignments = assignments.filter(
  (assignment) => assignment.contract_type === 'PERMANENT',
);

const contractorAssignments = assignments.filter(
  (assignment) => assignment.contract_type === 'CONTRACTOR',
);

const uniqueEmployeeCount = new Set(
  assignments.map((assignment) => assignment.employee_number),
).size;

const totalScheduledHours = assignments.reduce(
  (sum, assignment) =>
    sum + Number(assignment.assigned_hours || 0),
  0,
);

const totalPermanentCost = metrics.reduce(
  (sum, metric) =>
    sum + Number(metric.permanent_cost || 0),
  0,
);

const totalContractorCost = metrics.reduce(
  (sum, metric) =>
    sum + Number(metric.contractor_cost || 0),
  0,
);

const averageCoverage =
  metrics.length > 0
    ? metrics.reduce(
        (sum, metric) =>
          sum + Number(metric.coverage_percent || 0),
        0,
      ) / metrics.length
    : 0;

const allWithinTolerance =
  metrics.length > 0 &&
  metrics.every(
    (metric) => metric.within_tolerance === true,
  );

const statusClass =
  run.status === 'COMPLETED'
    ? 'success'
    : run.status === 'INFEASIBLE'
      ? 'danger'
      : 'warning';

const statusLabel =
  run.status === 'COMPLETED'
    ? 'Schedule completed'
    : run.status === 'INFEASIBLE'
      ? 'Schedule infeasible'
      : run.status || 'Unknown';

const coverageClass =
  metrics.length === 0
    ? 'neutral'
    : allWithinTolerance
      ? 'success-soft'
      : 'danger-soft';

const assignmentRows = assignments
  .map((assignment) => {
    const rowClass =
      assignment.contract_type === 'CONTRACTOR'
        ? 'contractor-row'
        : 'permanent-row';

    const contractClass =
      assignment.contract_type === 'CONTRACTOR'
        ? 'contractor-badge'
        : 'permanent-badge';

    return `
      <tr class="${rowClass}">
        <td>${formatDate(assignment.work_date)}</td>

        <td>
          <span class="shift-badge">
            ${escapeHtml(assignment.shift_code)}
          </span>
        </td>

        <td>${escapeHtml(assignment.time_of_day)}</td>

        <td class="employee-number">
          ${escapeHtml(assignment.employee_number)}
        </td>

        <td class="employee-name">
          ${escapeHtml(assignment.full_name)}
        </td>

        <td>
          <span class="contract-badge ${contractClass}">
            ${escapeHtml(assignment.contract_type)}
          </span>
        </td>

        <td class="number">
          ${number(assignment.assigned_hours, 2, 2)}
        </td>

        <td class="number">
          ${money(assignment.hourly_rate)}
        </td>

        <td class="number strong">
          ${money(assignment.assignment_cost)}
        </td>
      </tr>
    `;
  })
  .join('');

const metricRows = metrics
  .map((metric) => {
    const toleranceClass = metric.within_tolerance
      ? 'tolerance-ok'
      : 'tolerance-failed';

    const toleranceLabel = metric.within_tolerance
      ? 'Within tolerance'
      : 'Outside tolerance';

    return `
      <tr>
        <td>${formatDate(metric.demand_date)}</td>

        <td>
          <span class="period-badge">
            ${escapeHtml(metric.time_of_day)}
          </span>
        </td>

        <td class="number">
          ${number(metric.required_hours, 2, 2)}
        </td>

        <td class="number">
          ${number(metric.scheduled_hours, 2, 2)}
        </td>

        <td class="number strong">
          ${percentage(metric.coverage_percent)}
        </td>

        <td class="number">
          ${number(metric.permanent_hours, 2, 2)}
        </td>

        <td class="number">
          ${number(metric.contractor_hours, 2, 2)}
        </td>

        <td>
          <span class="tolerance-badge ${toleranceClass}">
            ${toleranceLabel}
          </span>
        </td>
      </tr>
    `;
  })
  .join('');

const assignmentsSection =
  assignments.length > 0
    ? `
      <section class="card">
        <div class="section-header">
          <div>
            <p class="eyebrow">Resource allocation</p>
            <h2>Employee assignments</h2>
          </div>

          <div class="section-stat">
            ${uniqueEmployeeCount}
            employee${uniqueEmployeeCount === 1 ? '' : 's'}
          </div>
        </div>

        <div class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Shift</th>
                <th>Period</th>
                <th>Employee</th>
                <th>Name</th>
                <th>Contract</th>
                <th class="number">Hours</th>
                <th class="number">Hourly rate</th>
                <th class="number">Cost</th>
              </tr>
            </thead>

            <tbody>
              ${assignmentRows}
            </tbody>
          </table>
        </div>

        <div class="legend">
          <span>
            <span class="legend-dot permanent-dot"></span>
            Permanent employee
          </span>

          <span>
            <span class="legend-dot contractor-dot"></span>
            Contractor
          </span>
        </div>
      </section>
    `
    : `
      <section class="card">
        <div class="section-header">
          <div>
            <p class="eyebrow">Resource allocation</p>
            <h2>Employee assignments</h2>
          </div>
        </div>

        <div class="empty-state">
          <div class="empty-icon">!</div>

          <div>
            <h3>No assignments were produced</h3>

            <p>
              The optimiser could not create a schedule that
              satisfies all demand and eligibility constraints
              for this run.
            </p>
          </div>
        </div>
      </section>
    `;

const metricsSection =
  metrics.length > 0
    ? `
      <section class="card">
        <div class="section-header">
          <div>
            <p class="eyebrow">Demand fulfilment</p>
            <h2>Coverage</h2>
          </div>

          <div class="section-stat ${coverageClass}">
            ${
              allWithinTolerance
                ? 'All periods within tolerance'
                : 'Review required'
            }
          </div>
        </div>

        <div class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>Date</th>
                <th>Period</th>
                <th class="number">Required</th>
                <th class="number">Scheduled</th>
                <th class="number">Coverage</th>
                <th class="number">Permanent</th>
                <th class="number">Contractor</th>
                <th>Result</th>
              </tr>
            </thead>

            <tbody>
              ${metricRows}
            </tbody>
          </table>
        </div>
      </section>
    `
    : '';

const html = `
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">

  <meta
    name="viewport"
    content="width=device-width, initial-scale=1"
  >

  <title>
    Workforce Schedule Run
    ${escapeHtml(run.schedule_run_id)}
  </title>

  <style>
    :root {
      color-scheme: light;

      --page-bg: #eef2f6;
      --card-bg: #ffffff;
      --surface-muted: #f8fafc;
      --border: #dbe3ec;

      --text-main: #172033;
      --text-muted: #64748b;
      --text-subtle: #94a3b8;

      --accent: #1d4ed8;

      --success-bg: #dcfce7;
      --success-text: #166534;
      --success-border: #bbf7d0;

      --danger-bg: #fee2e2;
      --danger-text: #991b1b;
      --danger-border: #fecaca;

      --warning-bg: #fef3c7;
      --warning-text: #92400e;
      --warning-border: #fde68a;

      --permanent-bg: #eff6ff;
      --permanent-text: #1d4ed8;
      --permanent-border: #bfdbfe;

      --contractor-bg: #fff7ed;
      --contractor-text: #9a3412;
      --contractor-border: #fed7aa;

      --shadow:
        0 1px 2px rgba(15, 23, 42, 0.04),
        0 8px 28px rgba(15, 23, 42, 0.08);
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      padding: 32px;

      background:
        radial-gradient(
          circle at top left,
          rgba(219, 234, 254, 0.65),
          transparent 32%
        ),
        var(--page-bg);

      color: var(--text-main);

      font-family:
        Inter,
        ui-sans-serif,
        system-ui,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        sans-serif;

      line-height: 1.45;
    }

    .container {
      width: min(96vw, 1680px);
      margin: 0 auto;
    }

    .card {
      margin-bottom: 20px;
      overflow: hidden;

      border: 1px solid var(--border);
      border-radius: 16px;

      background: var(--card-bg);
      box-shadow: var(--shadow);
    }

    .hero {
      padding: 26px 28px;
    }

    .hero-top {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 24px;
    }

    .eyebrow {
      margin: 0 0 4px;

      color: var(--accent);

      font-size: 12px;
      font-weight: 800;
      letter-spacing: 0.1em;
      text-transform: uppercase;
    }

    h1,
    h2,
    h3,
    p {
      margin-top: 0;
    }

    h1 {
      margin-bottom: 6px;

      font-size: clamp(28px, 3vw, 42px);
      line-height: 1.1;
      letter-spacing: -0.03em;
    }

    h2 {
      margin-bottom: 0;

      font-size: 22px;
      letter-spacing: -0.015em;
    }

    h3 {
      margin-bottom: 6px;
      font-size: 17px;
    }

    .subtitle {
      margin-bottom: 0;
      color: var(--text-muted);
      font-size: 15px;
    }

    .status {
      display: inline-flex;
      align-items: center;
      flex-shrink: 0;
      gap: 8px;

      padding: 9px 14px;

      border: 1px solid transparent;
      border-radius: 999px;

      font-size: 13px;
      font-weight: 800;
      white-space: nowrap;
    }

    .status-dot {
      width: 8px;
      height: 8px;

      border-radius: 50%;
      background: currentColor;
    }

    .success {
      border-color: var(--success-border);
      background: var(--success-bg);
      color: var(--success-text);
    }

    .danger {
      border-color: var(--danger-border);
      background: var(--danger-bg);
      color: var(--danger-text);
    }

    .warning {
      border-color: var(--warning-border);
      background: var(--warning-bg);
      color: var(--warning-text);
    }

    .context-grid {
      display: grid;
      grid-template-columns: repeat(6, minmax(0, 1fr));
      gap: 12px;

      margin-top: 24px;
    }

    .context-item {
      min-width: 0;
      padding: 13px 14px;

      border: 1px solid #e7edf4;
      border-radius: 11px;

      background: var(--surface-muted);
    }

    .label {
      display: block;
      margin-bottom: 5px;

      color: var(--text-muted);

      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.06em;
      text-transform: uppercase;
    }

    .value {
      overflow-wrap: anywhere;

      color: var(--text-main);

      font-size: 15px;
      font-weight: 750;
    }

    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(7, minmax(0, 1fr));
      gap: 12px;

      margin-top: 18px;
    }

    .kpi {
      position: relative;

      min-height: 112px;
      padding: 17px;
      overflow: hidden;

      border: 1px solid #e4eaf1;
      border-radius: 12px;

      background: #ffffff;
    }

    .kpi::after {
      position: absolute;
      right: -20px;
      bottom: -28px;

      width: 82px;
      height: 82px;

      border-radius: 50%;

      background: rgba(29, 78, 216, 0.05);
      content: "";
    }

    .kpi-title {
      position: relative;
      z-index: 1;

      color: var(--text-muted);

      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.055em;
      text-transform: uppercase;
    }

    .kpi-value {
      position: relative;
      z-index: 1;

      margin-top: 12px;

      font-size: clamp(23px, 2.2vw, 32px);
      font-weight: 800;
      line-height: 1;
      letter-spacing: -0.025em;
    }

    .kpi-note {
      position: relative;
      z-index: 1;

      margin-top: 8px;

      color: var(--text-muted);
      font-size: 12px;
    }

    .section-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 20px;

      padding: 21px 24px 17px;

      border-bottom: 1px solid var(--border);
    }

    .section-stat {
      padding: 7px 11px;

      border-radius: 999px;

      background: var(--surface-muted);
      color: var(--text-muted);

      font-size: 12px;
      font-weight: 750;
      white-space: nowrap;
    }

    .success-soft {
      background: var(--success-bg);
      color: var(--success-text);
    }

    .danger-soft {
      background: var(--danger-bg);
      color: var(--danger-text);
    }

    .neutral {
      background: var(--surface-muted);
      color: var(--text-muted);
    }

    .table-wrapper {
      width: 100%;
      overflow-x: auto;

      -webkit-overflow-scrolling: touch;
    }

    table {
      width: 100%;
      min-width: 980px;

      border-collapse: collapse;
      table-layout: auto;
    }

    thead {
      background: var(--surface-muted);
    }

    th,
    td {
      padding: 12px 15px;

      border-bottom: 1px solid #e8edf3;

      text-align: left;
      vertical-align: middle;
      white-space: nowrap;
    }

    th {
      color: #475569;

      font-size: 11px;
      font-weight: 850;
      letter-spacing: 0.045em;
      text-transform: uppercase;
    }

    td {
      color: #263247;
      font-size: 13px;
    }

    tbody tr:last-child td {
      border-bottom: 0;
    }

    tbody tr:hover {
      background: #fbfdff;
    }

    .number {
      text-align: right;
      font-variant-numeric: tabular-nums;
    }

    .strong {
      font-weight: 800;
    }

    .employee-number {
      font-family:
        "SFMono-Regular",
        Consolas,
        "Liberation Mono",
        monospace;

      font-weight: 750;
    }

    .employee-name {
      min-width: 160px;
      font-weight: 700;
    }

    .shift-badge,
    .period-badge,
    .contract-badge,
    .tolerance-badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;

      border: 1px solid transparent;
      border-radius: 999px;

      font-size: 11px;
      font-weight: 800;
      white-space: nowrap;
    }

    .shift-badge {
      min-width: 38px;
      padding: 5px 8px;

      border-color: #cbd5e1;
      background: #f8fafc;
      color: #334155;
    }

    .period-badge {
      padding: 5px 9px;

      border-color: #dbeafe;
      background: #eff6ff;
      color: #1e40af;
    }

    .contract-badge {
      padding: 5px 9px;
    }

    .permanent-badge {
      border-color: var(--permanent-border);
      background: var(--permanent-bg);
      color: var(--permanent-text);
    }

    .contractor-badge {
      border-color: var(--contractor-border);
      background: var(--contractor-bg);
      color: var(--contractor-text);
    }

    .contractor-row {
      background: rgba(255, 247, 237, 0.38);
    }

    .tolerance-badge {
      padding: 5px 9px;
    }

    .tolerance-ok {
      border-color: var(--success-border);
      background: var(--success-bg);
      color: var(--success-text);
    }

    .tolerance-failed {
      border-color: var(--danger-border);
      background: var(--danger-bg);
      color: var(--danger-text);
    }

    .legend {
      display: flex;
      flex-wrap: wrap;
      gap: 18px;

      padding: 13px 24px 16px;

      border-top: 1px solid var(--border);

      background: #fbfcfe;
      color: var(--text-muted);

      font-size: 12px;
    }

    .legend span {
      display: inline-flex;
      align-items: center;
      gap: 7px;
    }

    .legend-dot {
      width: 9px;
      height: 9px;
      border-radius: 50%;
    }

    .permanent-dot {
      background: #60a5fa;
    }

    .contractor-dot {
      background: #fb923c;
    }

    .empty-state {
      display: flex;
      align-items: flex-start;
      gap: 16px;

      margin: 22px;
      padding: 20px;

      border: 1px solid var(--warning-border);
      border-radius: 12px;

      background: #fffaf0;
      color: var(--warning-text);
    }

    .empty-state p {
      margin-bottom: 0;
      color: #9a5b16;
    }

    .empty-icon {
      display: grid;
      width: 34px;
      height: 34px;
      flex: 0 0 34px;
      place-items: center;

      border-radius: 50%;

      background: var(--warning-bg);

      font-weight: 900;
    }

    .footer-note {
      padding: 2px 4px 14px;

      color: var(--text-subtle);

      font-size: 11px;
      text-align: center;
    }

    @media (max-width: 1250px) {
      .context-grid {
        grid-template-columns:
          repeat(3, minmax(0, 1fr));
      }

      .kpi-grid {
        grid-template-columns:
          repeat(4, minmax(0, 1fr));
      }
    }

    @media (max-width: 760px) {
      body {
        padding: 14px;
      }

      .container {
        width: 100%;
      }

      .hero {
        padding: 20px;
      }

      .hero-top,
      .section-header {
        align-items: flex-start;
        flex-direction: column;
      }

      .context-grid {
        grid-template-columns:
          repeat(2, minmax(0, 1fr));
      }

      .kpi-grid {
        grid-template-columns:
          repeat(2, minmax(0, 1fr));
      }

      .section-header {
        padding: 18px;
      }
    }

    @media (max-width: 440px) {
      .context-grid,
      .kpi-grid {
        grid-template-columns: 1fr;
      }
    }

    @media print {
      body {
        padding: 0;
        background: #ffffff;
      }

      .container {
        width: 100%;
        max-width: none;
      }

      .card {
        box-shadow: none;
        break-inside: avoid;
      }

      .table-wrapper {
        overflow: visible;
      }

      table {
        min-width: 0;
      }

      th,
      td {
        white-space: normal;
      }
    }
  </style>
</head>

<body>
  <main class="container">
    <section class="card hero">
      <div class="hero-top">
        <div>
          <p class="eyebrow">
            Aviation workforce optimisation
          </p>

          <h1>Workforce Schedule</h1>

          <p class="subtitle">
            Deterministic schedule generated from eligibility,
            demand and cost constraints.
          </p>
        </div>

        <span class="status ${statusClass}">
          <span class="status-dot"></span>
          ${escapeHtml(statusLabel)}
        </span>
      </div>

      <div class="context-grid">
        <div class="context-item">
          <span class="label">Run ID</span>

          <div class="value">
            ${escapeHtml(run.schedule_run_id)}
          </div>
        </div>

        <div class="context-item">
          <span class="label">Contract</span>

          <div class="value">
            ${escapeHtml(run.contract_reference)}
          </div>
        </div>

        <div class="context-item">
          <span class="label">Customer</span>

          <div class="value">
            ${escapeHtml(run.customer_name)}
          </div>
        </div>

        <div class="context-item">
          <span class="label">Station</span>

          <div class="value">
            ${escapeHtml(run.station_code)}
          </div>
        </div>

        <div class="context-item">
          <span class="label">Planning date</span>

          <div class="value">
            ${formatDate(run.planning_from)}
          </div>
        </div>

        <div class="context-item">
          <span class="label">Solver result</span>

          <div class="value">
            ${escapeHtml(run.solver_status)}
          </div>
        </div>
      </div>

      <div class="kpi-grid">
        <div class="kpi">
          <div class="kpi-title">
            Employees used
          </div>

          <div class="kpi-value">
            ${uniqueEmployeeCount}
          </div>

          <div class="kpi-note">
            ${number(totalScheduledHours, 2, 2)}
            scheduled hours
          </div>
        </div>

        <div class="kpi">
          <div class="kpi-title">
            Permanent
          </div>

          <div class="kpi-value">
            ${permanentAssignments.length}
          </div>

          <div class="kpi-note">
            ${money(totalPermanentCost)}
            labour cost
          </div>
        </div>

        <div class="kpi">
          <div class="kpi-title">
            Contractors
          </div>

          <div class="kpi-value">
            ${contractorAssignments.length}
          </div>

          <div class="kpi-note">
            ${money(totalContractorCost)}
            labour cost
          </div>
        </div>

        <div class="kpi">
          <div class="kpi-title">
            Average coverage
          </div>

          <div class="kpi-value">
            ${
              metrics.length > 0
                ? percentage(averageCoverage)
                : '—'
            }
          </div>

          <div class="kpi-note">
            ${
              metrics.length > 0
                ? allWithinTolerance
                  ? 'All periods within tolerance'
                  : 'One or more periods require review'
                : 'No coverage metrics'
            }
          </div>
        </div>

        <div class="kpi">
          <div class="kpi-title">
            Total cost
          </div>

          <div class="kpi-value">
            ${money(run.total_cost)}
          </div>

          <div class="kpi-note">
            Scheduled labour cost
          </div>
        </div>

        <div class="kpi">
          <div class="kpi-title">
            Execution time
          </div>

          <div class="kpi-value">
            ${
              run.execution_time_ms === null ||
              run.execution_time_ms === undefined
                ? '—'
                : `${number(run.execution_time_ms)} ms`
            }
          </div>

          <div class="kpi-note">
            Optimiser runtime
          </div>
        </div>

        <div class="kpi">
          <div class="kpi-title">
            Schedule result
          </div>

          <div class="kpi-value">
            ${
              run.status === 'COMPLETED'
                ? 'Ready'
                : run.status === 'INFEASIBLE'
                  ? 'Blocked'
                  : escapeHtml(run.status || '—')
            }
          </div>

          <div class="kpi-note">
            ${
              escapeHtml(
                run.trigger_reason ||
                'No trigger reason supplied',
              )
            }
          </div>
        </div>
      </div>
    </section>

    ${metricsSection}
    ${assignmentsSection}

    <div class="footer-note">
      Schedule run
      ${escapeHtml(run.schedule_run_id)}
      ·
      ${escapeHtml(run.contract_reference)}
      ·
      ${formatDate(run.planning_from)}
    </div>
  </main>
</body>
</html>
`;

return [
  {
    json: {
      schedule_run_id: run.schedule_run_id,
      status: run.status,
      html,
    },
  },
];