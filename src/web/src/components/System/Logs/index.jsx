import '../System.css';
import { createLogsHubConnection } from '../../../lib/hubFactory';
import { downloadLogFile, getLogFile, getLogFiles } from '../../../lib/logs';
import { downloadFile, formatBytes, formatDate } from '../../../lib/util';
import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Button,
  ButtonGroup,
  Header,
  Icon,
  Message,
  Modal,
  Popup,
  Table,
} from 'semantic-ui-react';

const maxLogs = 500;

const filters = [
  {
    accessibleName: 'Show all severities',
    description: 'Show every severity so you can inspect the full live log feed.',
    label: 'All',
    level: 'all',
  },
  {
    accessibleName: 'Show information logs',
    color: 'blue',
    description: 'Show informational records to follow normal application activity.',
    label: 'Info',
    level: 'Information',
  },
  {
    accessibleName: 'Show warning logs',
    color: 'yellow',
    description: 'Show warnings to review conditions that may need attention.',
    label: 'Warn',
    level: 'Warning',
  },
  {
    accessibleName: 'Show error logs',
    color: 'red',
    description: 'Show errors to focus on failed operations and their causes.',
    label: 'Error',
    level: 'Error',
  },
  {
    accessibleName: 'Show debug logs',
    description: 'Show debug records when investigating detailed application behavior.',
    label: 'Debug',
    level: 'Debug',
  },
];

const levels = {
  Debug: 'DBG',
  Error: 'ERR',
  Information: 'INF',
  Warning: 'WRN',
};

const getErrorMessage = (error, fallback) =>
  error?.message || fallback;

const formatTimestamp = (timestamp) => {
  const date = new Date(timestamp);
  return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}:${date.getSeconds().toString().padStart(2, '0')}`;
};

const Logs = () => {
  const [logs, setLogs] = useState([]);
  const [filterLevel, setFilterLevel] = useState('all');
  const [connectionStatus, setConnectionStatus] = useState('connecting');
  const [connectionError, setConnectionError] = useState('');
  const [connectionAttempt, setConnectionAttempt] = useState(0);
  const [view, setView] = useState('live');
  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState('');
  const [historyAttempt, setHistoryAttempt] = useState(0);
  const [preview, setPreview] = useState(null);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewError, setPreviewError] = useState('');
  const previewRequestId = useRef(0);

  useEffect(() => () => { previewRequestId.current += 1; }, []);

  useEffect(() => {
    if (view !== 'live') return undefined;

    let active = true;
    const logsHub = createLogsHubConnection();

    logsHub.on('buffer', (buffer) => {
      if (!active) return;

      setLogs(Array.isArray(buffer) ? [...buffer].reverse().slice(0, maxLogs) : []);
      setConnectionStatus('connected');
      setConnectionError('');
    });

    logsHub.on('log', (log) => {
      if (!active) return;

      setLogs((current) => [log, ...current].slice(0, maxLogs));
      setConnectionStatus('connected');
      setConnectionError('');
    });

    logsHub.onreconnecting((error) => {
      if (!active) return;

      setConnectionStatus('reconnecting');
      setConnectionError(getErrorMessage(error, 'The live log connection was interrupted.'));
    });

    logsHub.onreconnected(() => {
      if (!active) return;

      setConnectionStatus('connected');
      setConnectionError('');
    });

    logsHub.onclose((error) => {
      if (!active) return;

      setConnectionStatus('disconnected');
      setConnectionError(getErrorMessage(error, 'The live log connection closed.'));
    });

    logsHub.start().then(
      () => {
        if (active) {
          setConnectionStatus('connected');
          setConnectionError('');
        }
      },
      (error) => {
        if (active) {
          setConnectionStatus('disconnected');
          setConnectionError(getErrorMessage(error, 'Unable to connect to live logs.'));
        }
      },
    );

    return () => {
      active = false;
      logsHub.stop().catch((error) => {
        console.error('[Logs] Failed to stop hub connection:', error);
      });
    };
  }, [connectionAttempt, view]);

  useEffect(() => {
    if (view !== 'history') return undefined;

    let active = true;

    getLogFiles().then(
      (files) => {
        if (active) setHistory(Array.isArray(files) ? files : []);
      },
      (error) => {
        if (active) setHistoryError(getErrorMessage(error, 'Unable to load retained log files.'));
      },
    ).finally(() => {
      if (active) setHistoryLoading(false);
    });

    return () => { active = false; };
  }, [historyAttempt, view]);

  const filteredLogs = useMemo(
    () =>
      filterLevel === 'all'
        ? logs
        : logs.filter((log) => log.level === filterLevel),
    [filterLevel, logs],
  );

  const retryConnection = () => {
    setConnectionError('');
    setConnectionStatus('connecting');
    setConnectionAttempt((attempt) => attempt + 1);
  };

  const selectHistory = () => {
    setHistoryLoading(true);
    setHistoryError('');
    if (view === 'history') {
      setHistoryAttempt((attempt) => attempt + 1);
    } else {
      setView('history');
    }
  };

  const refreshHistory = () => {
    setHistoryLoading(true);
    setHistoryError('');
    setHistoryAttempt((attempt) => attempt + 1);
  };

  const openPreview = async (file) => {
    const requestId = ++previewRequestId.current;
    setPreview({ file, content: '' });
    setPreviewLoading(true);
    setPreviewError('');

    try {
      const content = await getLogFile(file.name);
      if (requestId === previewRequestId.current) setPreview({ file, content });
    } catch (error) {
      if (requestId === previewRequestId.current) {
        setPreviewError(getErrorMessage(error, 'Unable to read this log file.'));
      }
    } finally {
      if (requestId === previewRequestId.current) setPreviewLoading(false);
    }
  };

  const download = async (file) => {
    try {
      const content = await downloadLogFile(file.name);
      downloadFile(content, file.name, 'text/plain');
    } catch (error) {
      setHistoryError(getErrorMessage(error, `Unable to download ${file.name}.`));
    }
  };

  const closePreview = () => {
    previewRequestId.current += 1;
    setPreview(null);
    setPreviewLoading(false);
    setPreviewError('');
  };

  const connectionMessage = {
    connected: null,
    connecting: {
      content: 'Recent log entries will appear here as they arrive.',
      header: 'Connecting to live logs',
      info: true,
    },
    disconnected: {
      content: connectionError,
      header: 'Live logs are disconnected',
      warning: true,
    },
    reconnecting: {
      content: connectionError
        ? `${connectionError} Buffered entries remain available while the connection recovers.`
        : 'Buffered entries remain available while the connection recovers.',
      header: 'Reconnecting to live logs',
      warning: true,
    },
  }[connectionStatus];

  return (
    <div className="logs">
      <Header as="h2">
        <Header.Content>System Logs</Header.Content>
        <Header.Subheader>
          {view === 'live'
            ? 'Monitor the most recent application records as they arrive.'
            : 'Browse and download retained daily application logs.'}
        </Header.Subheader>
      </Header>

      <div className="logs-controls">
        <ButtonGroup
          aria-label="Choose system log view"
          className="logs-view-buttons"
          role="group"
        >
          <Popup
            content="Monitor recent application records as they arrive."
            on={['hover', 'focus']}
            position="top center"
            trigger={(
              <Button
                active={view === 'live'}
                aria-pressed={view === 'live'}
                onClick={() => {
                  closePreview();
                  setConnectionStatus('connecting');
                  setConnectionError('');
                  setView('live');
                }}
                toggle
              >
                Live
              </Button>
            )}
          />
          <Popup
            content="Browse, inspect, and download retained daily log files."
            on={['hover', 'focus']}
            position="top center"
            trigger={(
              <Button
                active={view === 'history'}
                aria-pressed={view === 'history'}
                onClick={selectHistory}
                toggle
              >
                History
              </Button>
            )}
          />
        </ButtonGroup>

        {view === 'live' ? (
          <>
            <ButtonGroup
              aria-label="Filter log entries by severity"
              className="logs-filter-buttons"
              role="group"
            >
              {filters.map(({ accessibleName, color, description, label, level }) => {
                const active = filterLevel === level;
                return (
                  <Popup
                    key={level}
                    content={description}
                    on={['hover', 'focus']}
                    position="top center"
                    trigger={(
                      <Button
                        active={active}
                        aria-label={accessibleName}
                        aria-pressed={active}
                        color={active ? color : undefined}
                        onClick={() => setFilterLevel(level)}
                        toggle
                      >
                        {label}
                      </Button>
                    )}
                  />
                );
              })}
            </ButtonGroup>

            <span
              aria-live="polite"
              className="logs-count"
            >
              {connectionStatus === 'connected'
                ? `Showing ${filteredLogs.length} of ${logs.length} logs`
                : `Showing ${filteredLogs.length} of ${logs.length} buffered logs`}
            </span>
          </>
        ) : (
          <div className="logs-history-actions">
            <span aria-live="polite" className="logs-count">
              {historyLoading ? 'Loading retained logs…' : `${history.length} retained log${history.length === 1 ? '' : 's'}`}
            </span>
            <Popup
              content="Refresh the list of retained log files."
              on={['hover', 'focus']}
              position="top center"
              trigger={(
                <Button
                  aria-label="Refresh retained logs"
                  disabled={historyLoading}
                  icon
                  onClick={refreshHistory}
                  size="small"
                >
                  <Icon name="refresh" />
                </Button>
              )}
            />
          </div>
        )}
      </div>

      {view === 'live' && connectionMessage && (
        <Message
          className="logs-connection-message"
          info={connectionMessage.info}
          warning={connectionMessage.warning}
        >
          <Message.Header>{connectionMessage.header}</Message.Header>
          <p>{connectionMessage.content}</p>
          {connectionStatus === 'disconnected' && (
            <Popup
              content="Retry the live log connection to receive new records."
              on={['hover', 'focus']}
              position="top center"
              trigger={(
                <Button
                  aria-label="Retry live log connection"
                  className="logs-retry"
                  onClick={retryConnection}
                  size="small"
                >
                  Retry
                </Button>
              )}
            />
          )}
        </Message>
      )}

      {view === 'history' && (
        <>
          {historyError ? (
            <Message content={historyError} error role="alert" />
          ) : null}
          <div
            aria-label="Retained system log files"
            className="logs-table-scroll"
            role="region"
            tabIndex={0}
          >
            <Table aria-label="Retained system log files" className="logs-table" compact="very" unstackable>
              <Table.Header>
                <Table.Row>
                  <Table.HeaderCell>File</Table.HeaderCell>
                  <Table.HeaderCell>Last modified</Table.HeaderCell>
                  <Table.HeaderCell>Size</Table.HeaderCell>
                  <Table.HeaderCell textAlign="right">Actions</Table.HeaderCell>
                </Table.Row>
              </Table.Header>
              <Table.Body className="logs-table-body">
                {history.length === 0 ? (
                  <Table.Row>
                    <Table.Cell colSpan="4" textAlign="center">
                      {historyLoading ? 'Loading retained log files…' : 'No retained log files'}
                    </Table.Cell>
                  </Table.Row>
                ) : history.map((file) => (
                  <Table.Row key={file.name}>
                    <Table.Cell className="logs-history-name">{file.name}</Table.Cell>
                    <Table.Cell>{formatDate(file.lastModified)}</Table.Cell>
                    <Table.Cell>{formatBytes(file.length)}</Table.Cell>
                    <Table.Cell textAlign="right">
                      <div className="logs-history-row-actions">
                        <Popup
                          content={`Open ${file.name} to inspect its contents.`}
                          on={['hover', 'focus']}
                          position="top center"
                          trigger={(
                            <Button
                              aria-label={`View ${file.name}`}
                              icon
                              onClick={() => openPreview(file)}
                              size="small"
                            >
                              <Icon name="eye" />
                            </Button>
                          )}
                        />
                        <Popup
                          content={`Download ${file.name} for offline review.`}
                          on={['hover', 'focus']}
                          position="top center"
                          trigger={(
                            <Button
                              aria-label={`Download ${file.name}`}
                              icon
                              onClick={() => download(file)}
                              size="small"
                            >
                              <Icon name="download" />
                            </Button>
                          )}
                        />
                      </div>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table.Body>
            </Table>
          </div>
          <Modal
            onClose={closePreview}
            open={Boolean(preview)}
            size="large"
          >
            <Modal.Header>
              <Icon name="file alternate outline" />
              {preview?.file.name || 'Log file'}
            </Modal.Header>
            <Modal.Content scrolling>
              {previewError ? <Message content={previewError} error role="alert" /> : null}
              {previewLoading ? <Message info content="Loading log file…" /> : null}
              {!previewLoading && !previewError ? (
                <pre className="logs-history-preview">{preview?.content}</pre>
              ) : null}
            </Modal.Content>
            <Modal.Actions>
              <Popup
                content="Close this log preview and return to the retained files."
                on={['hover', 'focus']}
                trigger={(
                  <Button onClick={closePreview}>
                    Close
                  </Button>
                )}
              />
            </Modal.Actions>
          </Modal>
        </>
      )}

      {view === 'live' && (
        <div
          aria-label="System log entries"
          className="logs-table-scroll"
          role="region"
          tabIndex={0}
        >
          <Table
            aria-label="System log entries"
            className="logs-table"
            compact="very"
            unstackable
          >
            <Table.Header>
              <Table.Row>
                <Table.HeaderCell>Timestamp</Table.HeaderCell>
                <Table.HeaderCell>Level</Table.HeaderCell>
                <Table.HeaderCell>Message</Table.HeaderCell>
              </Table.Row>
            </Table.Header>
            <Table.Body className="logs-table-body">
              {filteredLogs.length === 0 ? (
                <Table.Row>
                  <Table.Cell
                    colSpan="3"
                    textAlign="center"
                  >
                    {connectionStatus === 'connected'
                      ? 'No logs match the selected filter'
                      : 'No buffered log entries'}
                  </Table.Cell>
                </Table.Row>
              ) : (
                filteredLogs.map((log, index) => (
                  <Table.Row
                    key={`${log.timestamp}-${log.level}-${index}`}
                    negative={log.level === 'Error'}
                    warning={log.level === 'Warning'}
                  >
                    <Table.Cell>
                      {formatTimestamp(log.timestamp)}
                    </Table.Cell>
                    <Table.Cell>{levels[log.level] || log.level}</Table.Cell>
                    <Table.Cell className="logs-table-message">
                      {log.message}
                    </Table.Cell>
                  </Table.Row>
                ))
              )}
            </Table.Body>
          </Table>
        </div>
      )}
    </div>
  );
};

export default Logs;
