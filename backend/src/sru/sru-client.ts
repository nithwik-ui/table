import axios, { AxiosInstance } from 'axios';
import * as cheerio from 'cheerio';

export interface TimetableEntry {
  day: string;
  start_time: string;
  end_time: string;
  subject: string;
  faculty: string;
  room: string;
  ltp: string;
  semester: string;
}

export class SRUClient {
  private axiosInstance: AxiosInstance;
  private baseUrl = 'https://timetable.sruniv.com';
  private csrfToken: string | null = null;
  private cookieHeader: string | null = null;

  constructor() {
    this.axiosInstance = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      timeout: 15000,
    });
  }

  /**
   * Initializes the session by scraping the /batchReport page for CSRF token and cookies.
   */
  public async initSession(): Promise<{ csrfToken: string; cookies: string }> {
    try {
      const response = await this.axiosInstance.get('/batchReport');
      const html = response.data;
      const $ = cheerio.load(html);

      const token = $('input[name="_token"]').val();
      if (!token || typeof token !== 'string') {
        throw new Error('CSRF token not found in /batchReport page');
      }

      this.csrfToken = token;

      // Extract set-cookie headers
      const setCookieHeaders = response.headers['set-cookie'];
      if (setCookieHeaders && setCookieHeaders.length > 0) {
        // Parse set-cookie header array to format: name=value; name=value
        const parsedCookies = setCookieHeaders.map(cookieStr => {
          return cookieStr.split(';')[0];
        });
        this.cookieHeader = parsedCookies.join('; ');
      }

      return {
        csrfToken: this.csrfToken,
        cookies: this.cookieHeader || '',
      };
    } catch (error) {
      console.error('Failed to initialize session:', error);
      throw error;
    }
  }

  /**
   * Initializes session specifically for the room free slots page.
   */
  public async initRoomSession(): Promise<{ csrfToken: string; cookies: string }> {
    try {
      const response = await this.axiosInstance.get('/room_free_slots');
      const html = response.data;
      const $ = cheerio.load(html);

      const token = $('input[name="_token"]').val();
      if (!token || typeof token !== 'string') {
        throw new Error('CSRF token not found in /room_free_slots page');
      }

      this.csrfToken = token;

      // Extract set-cookie headers
      const setCookieHeaders = response.headers['set-cookie'];
      if (setCookieHeaders && setCookieHeaders.length > 0) {
        const parsedCookies = setCookieHeaders.map(cookieStr => cookieStr.split(';')[0]);
        this.cookieHeader = parsedCookies.join('; ');
      }

      return {
        csrfToken: this.csrfToken,
        cookies: this.cookieHeader || '',
      };
    } catch (error) {
      console.error('Failed to initialize room session:', error);
      throw error;
    }
  }

  private getRequestHeaders() {
    const headers: Record<string, string> = {};
    if (this.cookieHeader) {
      headers['Cookie'] = this.cookieHeader;
    }
    return headers;
  }

  /**
   * Performs an HTTP request with auto-session retry on 419/CSRF errors
   */
  private async executeRequest<T>(requestFn: () => Promise<T>): Promise<T> {
    try {
      if (!this.csrfToken) {
        await this.initSession();
      }
      return await requestFn();
    } catch (error: any) {
      // Laravel returns 419 when CSRF token is mismatch or expired
      if (error.response && error.response.status === 419) {
        console.warn('Received HTTP 419, re-initializing session and retrying...');
        await this.initSession();
        return await requestFn();
      }
      throw error;
    }
  }

  private async executeRoomRequest<T>(requestFn: () => Promise<T>): Promise<T> {
    try {
      if (!this.csrfToken) {
        await this.initRoomSession();
      }
      return await requestFn();
    } catch (error: any) {
      if (error.response && error.response.status === 419) {
        console.warn('Received HTTP 419, re-initializing room session and retrying...');
        await this.initRoomSession();
        return await requestFn();
      }
      throw error;
    }
  }

  /**
   * Scrapes and returns all available degree codes.
   */
  public async getDegrees(): Promise<string[]> {
    return this.executeRequest(async () => {
      const response = await this.axiosInstance.get('/batchReport', {
        headers: this.getRequestHeaders(),
      });
      const $ = cheerio.load(response.data);
      const degrees: string[] = [];

      $('#degree option').each((_, el) => {
        const value = $(el).val();
        if (value && typeof value === 'string' && value.trim() !== '') {
          degrees.push(value.trim());
        }
      });

      return degrees;
    });
  }

  /**
   * Fetches the years available for a given degree.
   */
  public async getYears(degree: string): Promise<string[]> {
    return this.executeRequest(async () => {
      const response = await this.axiosInstance.get('/get-yearbpublic', {
        params: { degree },
        headers: this.getRequestHeaders(),
      });

      const data = response.data;
      if (data && data.yearList && Array.isArray(data.yearList)) {
        return data.yearList.map((item: any) => item.year.toString().trim());
      }
      return [];
    });
  }

  /**
   * Fetches the batches available for a given degree and year.
   */
  public async getBatches(degree: string, year: string): Promise<string[]> {
    return this.executeRequest(async () => {
      const response = await this.axiosInstance.get('/get-batchbpublic', {
        params: { degree, year },
        headers: this.getRequestHeaders(),
      });

      const data = response.data;
      if (data && data.batchList && Array.isArray(data.batchList)) {
        return data.batchList.map((item: any) => item.batch.toString().trim());
      }
      return [];
    });
  }

  /**
   * Fetches the raw timetable response for a given batch.
   */
  public async getDetailedTimetable(year: string, batch: string): Promise<any> {
    return this.executeRequest(async () => {
      if (!this.csrfToken) {
        throw new Error('CSRF token not initialized');
      }

      const params = new URLSearchParams();
      params.append('_token', this.csrfToken);
      params.append('year', year);
      params.append('batch', batch);

      const response = await this.axiosInstance.post('/searchBatchReport2Public', params, {
        headers: {
          ...this.getRequestHeaders(),
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': `${this.baseUrl}/batchReport`,
        },
      });

      return response.data;
    });
  }

  /**
   * Scrapes and returns all available faculty from the /report page.
   */
  public async getFacultyList(): Promise<Array<{ id: string; name: string }>> {
    return this.executeRequest(async () => {
      const response = await this.axiosInstance.get('/report', {
        headers: this.getRequestHeaders(),
      });
      const $ = cheerio.load(response.data);
      const faculties: Array<{ id: string; name: string }> = [];

      $('#faculty option').each((_, el) => {
        const value = $(el).val();
        const text = $(el).text();
        if (value && typeof value === 'string' && value.trim() !== '') {
          faculties.push({ id: value.trim(), name: text.trim() });
        }
      });

      return faculties;
    });
  }

  /**
   * Fetches the raw timetable response for a given faculty.
   */
  public async getFacultyTimetable(facultyId: string): Promise<any> {
    return this.executeRequest(async () => {
      if (!this.csrfToken) {
        throw new Error('CSRF token not initialized');
      }

      const params = new URLSearchParams();
      params.append('_token', this.csrfToken);
      params.append('faculty', facultyId);

      const response = await this.axiosInstance.post('/searchDueReport2Public', params, {
        headers: {
          ...this.getRequestHeaders(),
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': `${this.baseUrl}/report`,
        },
      });

      return response.data;
    });
  }

  /**
   * Fetches free classrooms for a given day and time.
   */
  public async getFreeRooms(day: string, time: string): Promise<Array<{ name: string; type: string }>> {
    return this.executeRoomRequest(async () => {
      if (!this.csrfToken) {
        throw new Error('CSRF token not initialized');
      }

      const params = new URLSearchParams();
      params.append('_token', this.csrfToken);
      params.append('day', day);
      params.append('time', time);

      const response = await this.axiosInstance.post('/room_free_slots', params, {
        headers: {
          ...this.getRequestHeaders(),
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': `${this.baseUrl}/room_free_slots`,
        },
      });

      const html = response.data;
      const $ = cheerio.load(html);
      const rooms: Array<{ name: string; type: string }> = [];

      // The results are in tables with class "table"
      $('.table tbody tr').each((_, el) => {
        const tds = $(el).find('td');
        if (tds.length >= 2) {
          const roomCell = $(tds[1]);
          const badge = roomCell.find('.badge');
          
          let type = badge.text().trim();
          // The name is the text inside the td but excluding the badge text. 
          // An easy way is to get the full text, remove the badge text, and trim trailing hyphens.
          let name = roomCell.text().replace(type, '').replace('-', '').trim();

          if (name) {
            rooms.push({ name, type });
          }
        }
      });

      return rooms;
    });
  }

  /**
   * Normalizes the raw SRU timetable JSON response.
   */
  public normalize(raw: any): TimetableEntry[] {
    const entries: TimetableEntry[] = [];

    if (!raw || !raw.success || typeof raw.data !== 'object' || Array.isArray(raw.data)) {
      return entries;
    }

    const dataObj = raw.data;
    const days = Object.keys(dataObj);

    for (const day of days) {
      const timeSlots = dataObj[day];
      if (typeof timeSlots !== 'object' || Array.isArray(timeSlots)) {
        continue;
      }

      const times = Object.keys(timeSlots);
      for (const timeKey of times) {
        const schedules = timeSlots[timeKey];
        if (!Array.isArray(schedules)) {
          continue;
        }

        for (const item of schedules) {
          // Calculate end time (normally 1 hour after start time)
          const start_time = timeKey.trim();
          const end_time = this.calculateEndTime(start_time);

          entries.push({
            day: day.trim(),
            start_time,
            end_time,
            subject: (item.subject || '').toString().trim(),
            faculty: (item.facultyName || '').toString().trim(),
            room: (item.room_name || '').toString().trim(),
            ltp: (item.ltp || '').toString().trim(),
            semester: (item.semester || '').toString().trim(),
          });
        }
      }
    }

    return entries;
  }

  private calculateEndTime(startTime: string): string {
    const parts = startTime.split(':');
    if (parts.length < 2) {
      return startTime;
    }
    const hours = parseInt(parts[0], 10);
    const minutes = parts[1];
    if (isNaN(hours)) {
      return startTime;
    }
    const endHours = (hours + 1).toString().padStart(2, '0');
    return `${endHours}:${minutes}`;
  }
}
