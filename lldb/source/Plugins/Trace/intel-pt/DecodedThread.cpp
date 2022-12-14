//===-- DecodedThread.cpp -------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "DecodedThread.h"

#include <intel-pt.h>

#include "TraceCursorIntelPT.h"

#include <memory>

using namespace lldb;
using namespace lldb_private;
using namespace lldb_private::trace_intel_pt;
using namespace llvm;

bool lldb_private::trace_intel_pt::IsLibiptError(int libipt_status) {
  return libipt_status < 0;
}

bool lldb_private::trace_intel_pt::IsEndOfStream(int libipt_status) {
  return libipt_status == -pte_eos;
}

bool lldb_private::trace_intel_pt::IsTscUnavailable(int libipt_status) {
  return libipt_status == -pte_no_time;
}

char IntelPTError::ID;

IntelPTError::IntelPTError(int libipt_error_code, lldb::addr_t address)
    : m_libipt_error_code(libipt_error_code), m_address(address) {
  assert(libipt_error_code < 0);
}

void IntelPTError::log(llvm::raw_ostream &OS) const {
  OS << pt_errstr(pt_errcode(m_libipt_error_code));
  if (m_address != LLDB_INVALID_ADDRESS && m_address > 0)
    OS << formatv(": {0:x+16}", m_address);
}

bool DecodedThread::TSCRange::InRange(uint64_t item_index) const {
  return item_index >= first_item_index &&
         item_index < first_item_index + items_count;
}

bool DecodedThread::NanosecondsRange::InRange(uint64_t item_index) const {
  return item_index >= first_item_index &&
         item_index < first_item_index + items_count;
}

double DecodedThread::NanosecondsRange::GetInterpolatedTime(
    uint64_t item_index, uint64_t begin_of_time_nanos,
    const LinuxPerfZeroTscConversion &tsc_conversion) const {
  uint64_t items_since_last_tsc = item_index - first_item_index;

  auto interpolate = [&](uint64_t next_range_start_ns) {
    if (next_range_start_ns == nanos) {
      // If the resolution of the conversion formula is bad enough to consider
      // these two timestamps as equal, then we just increase the next one by 1
      // for correction
      next_range_start_ns++;
    }
    long double item_duration =
        static_cast<long double>(items_count) / (next_range_start_ns - nanos);
    return (nanos - begin_of_time_nanos) + items_since_last_tsc * item_duration;
  };

  if (!next_range) {
    // If this is the last TSC range, so we have to extrapolate. In this case,
    // we assume that each instruction took one TSC, which is what an
    // instruction would take if no parallelism is achieved and the frequency
    // multiplier is 1.
    return interpolate(tsc_conversion.ToNanos(tsc + items_count));
  }
  if (items_count < (next_range->tsc - tsc)) {
    // If the numbers of items in this range is less than the total TSC duration
    // of this range, i.e. each instruction taking longer than 1 TSC, then we
    // can assume that something else happened between these TSCs (e.g. a
    // context switch, change to kernel, decoding errors, etc). In this case, we
    // also assume that each instruction took 1 TSC. A proper way to improve
    // this would be to analize the next events in the trace looking for context
    // switches or trace disablement events, but for now, as we only want an
    // approximation, we keep it simple. We are also guaranteed that the time in
    // nanos of the next range is different to the current one, just because of
    // the definition of a NanosecondsRange.
    return interpolate(
        std::min(tsc_conversion.ToNanos(tsc + items_count), next_range->nanos));
  }

  // In this case, each item took less than 1 TSC, so some parallelism was
  // achieved, which is an indication that we didn't suffered of any kind of
  // interruption.
  return interpolate(next_range->nanos);
}

uint64_t DecodedThread::GetItemsCount() const { return m_item_kinds.size(); }

lldb::addr_t
DecodedThread::GetInstructionLoadAddress(uint64_t item_index) const {
  return m_item_data[item_index].load_address;
}

ThreadSP DecodedThread::GetThread() { return m_thread_sp; }

DecodedThread::TraceItemStorage &
DecodedThread::CreateNewTraceItem(lldb::TraceItemKind kind) {
  m_item_kinds.push_back(kind);
  m_item_data.emplace_back();
  if (m_last_tsc)
    (*m_last_tsc)->second.items_count++;
  if (m_last_nanoseconds)
    (*m_last_nanoseconds)->second.items_count++;
  return m_item_data.back();
}

void DecodedThread::NotifyTsc(TSC tsc) {
  if (m_last_tsc && (*m_last_tsc)->second.tsc == tsc)
    return;

  m_last_tsc =
      m_tscs.emplace(GetItemsCount(), TSCRange{tsc, 0, GetItemsCount()}).first;

  if (m_tsc_conversion) {
    uint64_t nanos = m_tsc_conversion->ToNanos(tsc);
    if (!m_last_nanoseconds || (*m_last_nanoseconds)->second.nanos != nanos) {
      m_last_nanoseconds =
          m_nanoseconds
              .emplace(GetItemsCount(), NanosecondsRange{nanos, tsc, nullptr, 0,
                                                         GetItemsCount()})
              .first;
      if (*m_last_nanoseconds != m_nanoseconds.begin()) {
        auto prev_range = prev(*m_last_nanoseconds);
        prev_range->second.next_range = &(*m_last_nanoseconds)->second;
      }
    }
  }
  AppendEvent(lldb::eTraceEventHWClockTick);
}

void DecodedThread::NotifyCPU(lldb::cpu_id_t cpu_id) {
  if (!m_last_cpu || *m_last_cpu != cpu_id) {
    m_cpus.emplace(GetItemsCount(), cpu_id);
    m_last_cpu = cpu_id;
    AppendEvent(lldb::eTraceEventCPUChanged);
  }
}

Optional<lldb::cpu_id_t>
DecodedThread::GetCPUByIndex(uint64_t item_index) const {
  auto it = m_cpus.upper_bound(item_index);
  if (it == m_cpus.begin())
    return None;
  return prev(it)->second;
}

Optional<DecodedThread::TSCRange>
DecodedThread::GetTSCRangeByIndex(uint64_t item_index) const {
  auto next_it = m_tscs.upper_bound(item_index);
  if (next_it == m_tscs.begin())
    return None;
  return prev(next_it)->second;
}

Optional<DecodedThread::NanosecondsRange>
DecodedThread::GetNanosecondsRangeByIndex(uint64_t item_index) {
  auto next_it = m_nanoseconds.upper_bound(item_index);
  if (next_it == m_nanoseconds.begin())
    return None;
  return prev(next_it)->second;
}

void DecodedThread::AppendEvent(lldb::TraceEvent event) {
  CreateNewTraceItem(lldb::eTraceItemKindEvent).event = event;
  m_events_stats.RecordEvent(event);
}

void DecodedThread::AppendInstruction(const pt_insn &insn) {
  CreateNewTraceItem(lldb::eTraceItemKindInstruction).load_address = insn.ip;
}

void DecodedThread::AppendError(const IntelPTError &error) {
  // End of stream shouldn't be a public error
  if (IsEndOfStream(error.GetLibiptErrorCode()))
    return;
  CreateNewTraceItem(lldb::eTraceItemKindError).error =
      ConstString(error.message()).AsCString();
}

void DecodedThread::AppendCustomError(StringRef err) {
  CreateNewTraceItem(lldb::eTraceItemKindError).error =
      ConstString(err).AsCString();
}

lldb::TraceEvent DecodedThread::GetEventByIndex(int item_index) const {
  return m_item_data[item_index].event;
}

void DecodedThread::LibiptErrorsStats::RecordError(int libipt_error_code) {
  libipt_errors_counts[pt_errstr(pt_errcode(libipt_error_code))]++;
  total_count++;
}

void DecodedThread::RecordTscError(int libipt_error_code) {
  m_tsc_errors_stats.RecordError(libipt_error_code);
}

const DecodedThread::LibiptErrorsStats &
DecodedThread::GetTscErrorsStats() const {
  return m_tsc_errors_stats;
}

const DecodedThread::EventsStats &DecodedThread::GetEventsStats() const {
  return m_events_stats;
}

void DecodedThread::EventsStats::RecordEvent(lldb::TraceEvent event) {
  events_counts[event]++;
  total_count++;
}

lldb::TraceItemKind
DecodedThread::GetItemKindByIndex(uint64_t item_index) const {
  return static_cast<lldb::TraceItemKind>(m_item_kinds[item_index]);
}

const char *DecodedThread::GetErrorByIndex(uint64_t item_index) const {
  return m_item_data[item_index].error;
}

DecodedThread::DecodedThread(
    ThreadSP thread_sp,
    const llvm::Optional<LinuxPerfZeroTscConversion> &tsc_conversion)
    : m_thread_sp(thread_sp), m_tsc_conversion(tsc_conversion) {}

size_t DecodedThread::CalculateApproximateMemoryUsage() const {
  return sizeof(TraceItemStorage) * m_item_data.size() +
         sizeof(uint8_t) * m_item_kinds.size() +
         (sizeof(uint64_t) + sizeof(TSC)) * m_tscs.size() +
         (sizeof(uint64_t) + sizeof(uint64_t)) * m_nanoseconds.size() +
         (sizeof(uint64_t) + sizeof(lldb::cpu_id_t)) * m_cpus.size();
}
