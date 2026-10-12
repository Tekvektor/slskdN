// <copyright file="TransferTable.test.jsx" company="slskdN Team">
//     Copyright (c) slskdN Team. All rights reserved.
// </copyright>

import TransferTable from './TransferTable';
import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { ALL_COLUMNS } from '../../lib/transferColumns';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

describe('TransferTable', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.stubGlobal(
      'ResizeObserver',
      class ResizeObserver {
        disconnect() {}

        observe() {}
      },
    );
  });

  afterEach(() => {
    localStorage.clear();
    vi.unstubAllGlobals();
  });

  const renderTable = (transfers = [], selectedFiles = []) => render(
    <MemoryRouter>
      <TransferTable
        direction="download"
        onCancel={vi.fn()}
        onCancelSelected={vi.fn()}
        onOpenRequest={vi.fn()}
        onRemove={vi.fn()}
        onRemoveSelected={vi.fn()}
        onRetry={vi.fn()}
        onRetrySelected={vi.fn()}
        onSelectAll={vi.fn()}
        onSelectionChange={vi.fn()}
        selectedFiles={selectedFiles}
        selectedKeys={new Set()}
        transfers={transfers}
      />
    </MemoryRouter>,
  );

  it('labels the column chooser', () => {
    renderTable();

    expect(
      screen.getByRole('button', { name: 'Choose transfer table columns' }),
    ).toBeInTheDocument();
  });

  it('explains the scope of each selected-transfer action', async () => {
    renderTable([], [{ id: 'transfer-1' }, { id: 'transfer-2' }]);

    for (const [label, tooltip] of [
      ['Retry', 'Retry all 2 selected transfers.'],
      ['Cancel', 'Cancel all 2 selected transfers.'],
      ['Remove', 'Remove all 2 selected transfers from the list.'],
    ]) {
      const button = screen.getByRole('button', { name: label });
      fireEvent.mouseEnter(button);

      expect(await screen.findByText(tooltip)).toBeInTheDocument();
    }
  });

  it('applies each resize movement from the drag-start width', () => {
    renderTable();

    const handle = screen.getByLabelText('Resize Name column');
    fireEvent.mouseDown(handle, { clientX: 100 });
    fireEvent.mouseMove(document, { clientX: 120 });
    fireEvent.mouseMove(document, { clientX: 121 });
    fireEvent.mouseUp(document);

    const saved = JSON.parse(localStorage.getItem('slskdn-transfer-columns-download'));
    expect(saved.widths.name).toBe(221);
  });

  it('resets persisted transfer column widths', () => {
    renderTable();

    const handle = screen.getByLabelText('Resize Name column');
    fireEvent.mouseDown(handle, { clientX: 100 });
    fireEvent.mouseMove(document, { clientX: 260 });
    fireEvent.mouseUp(document);

    fireEvent.click(screen.getByRole('button', { name: 'Reset transfer column widths' }));

    const saved = JSON.parse(localStorage.getItem('slskdn-transfer-columns-download'));
    expect(saved.widths.name).toBe(200);
  });

  it('uses persisted column order for both headers and rows', () => {
    localStorage.setItem(
      'slskdn-transfer-columns-download',
      JSON.stringify({
        order: ['peer', 'name', 'size'],
        visible: Object.fromEntries(
          ALL_COLUMNS.map(({ key }) => [key, ['name', 'peer', 'size'].includes(key)]),
        ),
        widths: { name: 200, peer: 90, size: 120 },
      }),
    );

    const { container } = renderTable([{
      direction: 'Download',
      filename: 'Artist/Track.flac',
      id: 'transfer-1',
      size: 10,
      state: 'Queued',
      username: 'peer-one',
    }]);

    const headerKeys = [...container.querySelectorAll('.transfer-header-cell')]
      .map((element) => element.dataset.colkey);
    const rowKeys = [...container.querySelectorAll('.transfer-row:not(.transfer-header-row) [data-colkey]')]
      .map((element) => element.dataset.colkey);

    expect(headerKeys).toEqual(['peer', 'name', 'size']);
    expect(rowKeys).toEqual(['peer', 'name', 'size']);
    expect(headerKeys).not.toContain('actions');
  });

  const completedTransfer = {
    averageSpeed: 2_097_152,
    direction: 'Upload',
    filename: 'Music/Artist/Album/01. Track.flac',
    id: 'transfer-done',
    percentComplete: 100,
    size: 8_600_000,
    state: 'Completed, Succeeded',
    username: 'peer-one',
  };

  it('aligns numeric headers the same way as their cells', () => {
    const { container } = renderTable([completedTransfer]);

    const numericHeaders = [...container.querySelectorAll('.transfer-header-cell.transfer-cell-num')]
      .map((element) => element.dataset.colkey);
    const numericCells = [...container.querySelectorAll('.transfer-row:not(.transfer-header-row) .transfer-cell-num')]
      .map((element) => element.dataset.colkey);

    expect(numericHeaders).toEqual(expect.arrayContaining(['size', 'progress', 'speed']));
    expect(numericHeaders).toEqual(numericCells);
    expect(numericHeaders).not.toContain('name');
  });

  it('shows a full progress bar and the average speed for a completed transfer', () => {
    const { container } = renderTable([completedTransfer]);
    const row = container.querySelector('.transfer-row:not(.transfer-header-row)');

    const progress = row.querySelector('[data-colkey="progress"]');
    expect(progress.querySelector('.transfer-progress-fill').style.width).toBe('100%');
    expect(progress.querySelector('.transfer-state-pill')).toBeNull();

    const speed = row.querySelector('[data-colkey="speed"] .transfer-speed-final');
    expect(speed).not.toBeNull();
    expect(speed.textContent).toMatch(/\/s$/);
  });

  it('keeps the state pill in the progress column for transfers that are not finished', () => {
    const { container } = renderTable([{ ...completedTransfer, averageSpeed: 0, percentComplete: 0, state: 'Queued, Remotely' }]);
    const row = container.querySelector('.transfer-row:not(.transfer-header-row)');

    expect(row.querySelector('[data-colkey="progress"] .transfer-state-pill')).not.toBeNull();
    expect(row.querySelector('[data-colkey="speed"]').textContent).toBe('-');
  });
});
