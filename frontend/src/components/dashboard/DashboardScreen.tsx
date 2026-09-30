"use client";

import { useEffect, useState } from "react";
import { DataTable } from "@/components/ui/DataTable";
import { ErrorState, LoadingState, StatusBadge } from "@/components/ui/Feedback";
import { getDashboard } from "@/services/records.service";
import type { ChartBar, DashboardSnapshot, StatusSlice } from "@/types/domain";

const markers = [
  { name: "Kachchh", x: 78, y: 118 },
  { name: "Mumbai", x: 92, y: 168 },
  { name: "Goa", x: 108, y: 198 },
  { name: "Kochi", x: 118, y: 236 },
  { name: "Chennai", x: 168, y: 230 },
  { name: "Puri", x: 196, y: 176 },
  { name: "Sundarbans", x: 214, y: 150 },
];

export function DashboardScreen() {
  const [data, setData] = useState<DashboardSnapshot | null>(null);
  const [error, setError] = useState("");
  const [welcome, setWelcome] = useState<string | null>(null);

  function load() {
    setError("");
    setData(null);
    getDashboard().then(setData).catch((caught: unknown) => {
      setError(caught instanceof Error ? caught.message : "Unable to load the dashboard.");
    });
  }

  useEffect(() => {
    setWelcome(new URLSearchParams(window.location.search).get("welcome"));
    load();
  }, []);

  return (
    <div className="page">
      <header className="page-head">
        <div>
          <h1>Dashboard</h1>
          <p>Coastal interventions, MRV records and approvals across India’s coastline.</p>
        </div>
      </header>
      {welcome ? <p className="welcome" role="status">Access request <strong>{welcome}</strong> has been submitted for review.</p> : null}
      {!data && !error ? <LoadingState label="Loading dashboard…" /> : null}
      {error ? <ErrorState message={error} onRetry={load} /> : null}
      {data ? (
        <>
          <section className="kpi-grid" aria-label="Summary">
            {data.kpis.map((kpi) => (
              <article key={kpi.id} className="kpi">
                <img src={kpi.icon} alt="" />
                <div><p>{kpi.label}</p><strong>{kpi.value}</strong><small>{kpi.note}</small></div>
              </article>
            ))}
          </section>
          <section className="dash-grid">
            <article className="panel" id="coastal-map">
              <header><h2>Coastal coverage</h2><p>Active sites along the mainland and island coasts.</p></header>
              <CoastalMap />
            </article>
            <article className="panel">
              <header><h2>Submission status</h2><p>Share of records by current state.</p></header>
              <Donut slices={data.slices} />
            </article>
          </section>
          <section className="panel">
            <header><h2>Interventions by state</h2><p>Open and completed works in coastal states and UTs.</p></header>
            <BarChart bars={data.bars} />
          </section>
          <section className="panel">
            <header><h2>Recent interventions</h2><p>Latest updates from implementing agencies.</p></header>
            <DataTable
              rows={data.recent}
              rowKey={(row) => row.id}
              columns={[
                { key: "id", header: "ID", render: (row) => row.id },
                { key: "title", header: "Intervention", render: (row) => row.title },
                { key: "state", header: "State / UT", render: (row) => row.state },
                { key: "status", header: "Status", render: (row) => <StatusBadge status={row.status} /> },
                { key: "updated", header: "Updated", render: (row) => row.updated },
              ]}
            />
          </section>
        </>
      ) : null}
    </div>
  );
}

export function CoastalMap() {
  return (
    <div className="map-frame">
      <svg viewBox="0 0 280 340" role="img" aria-label="Map of India with coastal sites marked">
        <rect width="280" height="340" rx="16" fill="#e7f4fb" />
        <path d="M118 28c18-10 34-6 46 8 8 10 18 12 24 24 6 14-2 22 2 34 6 16 18 18 16 34-2 18-18 22-16 40 2 16 12 26 6 42-8 18-4 30-18 40-16 12-8 28-24 36-18 8-22 24-40 22-16-2-24 10-40 4-14-6-10-22-22-32-10-8-22-10-24-26-2-18 14-26 12-44-2-16-16-22-12-40 4-20 18-22 18-40 0-16-8-26 4-38 12-12 16-28 28-36 8-6 18-8 20-18z" fill="#d7efe3" stroke="#7db89a" />
        {markers.map((marker) => (
          <g key={marker.name}>
            <circle cx={marker.x} cy={marker.y} r="5" fill="#4a2bc2" />
            <text x={marker.x + 8} y={marker.y + 4} fontSize="9" fill="#16324d">{marker.name}</text>
          </g>
        ))}
      </svg>
    </div>
  );
}

function Donut({ slices }: { slices: StatusSlice[] }) {
  const total = slices.reduce((sum, slice) => sum + slice.value, 0) || 1;
  let cursor = 0;
  const gradient = slices.map((slice) => {
    const start = cursor;
    cursor += (slice.value / total) * 100;
    return `${slice.color} ${start}% ${cursor}%`;
  }).join(", ");
  return (
    <div className="donut-wrap">
      <div className="donut" style={{ background: `conic-gradient(${gradient})` }} aria-hidden="true"><span>{total}%</span></div>
      <ul>
        {slices.map((slice) => (
          <li key={slice.label}><i style={{ background: slice.color }} />{slice.label}<strong>{slice.value}%</strong></li>
        ))}
      </ul>
    </div>
  );
}

function BarChart({ bars }: { bars: ChartBar[] }) {
  const max = Math.max(...bars.map((bar) => bar.value), 1);
  return (
    <div className="bars" role="img" aria-label="Bar chart of interventions by state">
      {bars.map((bar) => (
        <div key={bar.label} className="bar-col">
          <span className="bar-value">{bar.value}</span>
          <div className="bar-track"><div style={{ height: `${(bar.value / max) * 100}%` }} /></div>
          <span className="bar-label">{bar.label}</span>
        </div>
      ))}
    </div>
  );
}
