import api from './api';

export const getLogFiles = async () => (await api.get('/logs/files')).data;

export const getLogFile = async (fileName) => (
  await api.get(`/logs/files/${encodeURIComponent(fileName)}`, { responseType: 'text' })
).data;

export const downloadLogFile = async (fileName) => (
  await api.get(`/logs/files/${encodeURIComponent(fileName)}/download`, { responseType: 'blob' })
).data;
